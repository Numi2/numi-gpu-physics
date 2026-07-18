#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PREREGISTRATION="ValidationInputs/formation-flight-subcell-source-census-v1.json"
ARCHIVE="ValidationArtifacts/formation-flight-subcell-source-census"
TOOL="Tools/FormationSubcellSourceCensus/.build/release/FormationSubcellSourceCensusCLI"
RESOLUTIONS="${BIRDFLOW_FORMATION_SUBCELL_SOURCE_RESOLUTIONS:-16 18 20}"

python3 - "$PREREGISTRATION" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

root = Path.cwd()
prereg = json.load(open(sys.argv[1]))
if not prereg["preregisteredBeforeTranslatedCFD"]:
    raise SystemExit("subcell source experiment was not preregistered")
for group in ("lockedInputs", "lockedImplementation", "lockedAnalysis"):
    for item in prereg[group]:
        actual = hashlib.sha256((root / item["path"]).read_bytes()).hexdigest()
        if actual != item["sha256"]:
            raise SystemExit(f"locked file changed: {item['path']}")
print("subcell source preregistration, inputs, implementation, and analysis verified")
PY

swift build -c release --package-path Tools/FormationSubcellSourceCensus

smoke="$ARCHIVE/c8-instrumentation-smoke"
if [[ ! -f "$smoke/formation-flight-subcell-source-report.json" ]]; then
  "$TOOL" \
    --chord-cells 8 \
    --cycles 3 \
    --leader-phase 0.785 \
    --follower-offset-chords 0,0,-3 \
    --phase-offset 0.25 \
    --subcell-offset-cells 0.25,0.25,0.75 \
    --archive "$smoke" >/dev/null
fi
python3 - "$smoke/formation-flight-subcell-source-report.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
if not report["gates"]["passed"]:
    raise SystemExit("c8 instrumentation smoke failed")
if len(report["boundarySourceCensus"]["samples"]) != 2:
    raise SystemExit("c8 instrumentation smoke is incomplete")
print("c8 translated source instrumentation smoke passed")
PY

for resolution in $RESOLUTIONS; do
  case "$resolution" in
    16|18|20) ;;
    *) echo "unsupported source resolution: $resolution" >&2; exit 1 ;;
  esac
  directory="$ARCHIVE/c${resolution}-median-phase"
  report="$directory/formation-flight-subcell-source-report.json"
  if [[ -f "$report" ]]; then
    python3 - "$report" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
if not report["gates"]["passed"]:
    raise SystemExit(f"existing source run failed: {sys.argv[1]}")
if report["subcellOffsetCells"] != [0.25, 0.25, 0.75]:
    raise SystemExit(f"existing source run has the wrong offset: {sys.argv[1]}")
print(f"reusing passed translated source run: {sys.argv[1]}")
PY
    continue
  fi
  "$TOOL" \
    --chord-cells "$resolution" \
    --cycles 5 \
    --leader-phase 0.785 \
    --follower-offset-chords 0,0,-3 \
    --phase-offset 0.25 \
    --subcell-offset-cells 0.25,0.25,0.75 \
    --archive "$directory" >/dev/null
done

if [[ -f "$ARCHIVE/c16-median-phase/formation-flight-subcell-source-report.json" \
   && -f "$ARCHIVE/c18-median-phase/formation-flight-subcell-source-report.json" \
   && -f "$ARCHIVE/c20-median-phase/formation-flight-subcell-source-report.json" ]]; then
  python3 Scripts/analyze-formation-subcell-source-census.py
  python3 Scripts/audit-formation-subcell-source-census.py
fi
