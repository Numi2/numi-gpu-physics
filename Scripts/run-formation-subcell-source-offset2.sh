#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PREREGISTRATION="ValidationInputs/formation-flight-subcell-source-offset2-v1.json"
ARCHIVE="ValidationArtifacts/formation-flight-subcell-source-offset2"
TOOL="Tools/FormationSubcellSourceCensus/.build/release/FormationSubcellSourceCensusCLI"
OFFSET="0.5,0.75,0.5"
RESOLUTIONS="${BIRDFLOW_FORMATION_SUBCELL_SOURCE_RESOLUTIONS:-16 18 20}"

python3 - "$PREREGISTRATION" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

root = Path.cwd()
prereg = json.load(open(sys.argv[1]))
if not prereg["preregisteredBeforeTranslatedCFD"]:
    raise SystemExit("alternate-offset experiment was not preregistered")
for group in ("lockedInputs", "lockedImplementation", "lockedAnalysis"):
    for item in prereg[group]:
        actual = hashlib.sha256((root / item["path"]).read_bytes()).hexdigest()
        if actual != item["sha256"]:
            raise SystemExit(f"locked file changed: {item['path']}")
selection = json.load(open(root / prereg["selectionRule"]["source"]))
candidate = selection["topEightCandidates"][prereg["selectionRule"]["zeroBasedRank"]]
if candidate["offsetCells"] != prereg["lockedConfiguration"]["subcellOffsetCells"]:
    raise SystemExit("locked candidate rank no longer selects the preregistered offset")
print("alternate-offset preregistration, inputs, implementation, and analysis verified")
PY

swift build -c release --package-path Tools/FormationSubcellSourceCensus

for resolution in $RESOLUTIONS; do
  case "$resolution" in
    16|18|20) ;;
    *) echo "unsupported source resolution: $resolution" >&2; exit 1 ;;
  esac
  directory="$ARCHIVE/c${resolution}-offset2"
  report="$directory/formation-flight-subcell-source-report.json"
  if [[ -f "$report" ]]; then
    python3 - "$report" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
if not report["gates"]["passed"]:
    raise SystemExit(f"existing alternate-offset source run failed: {sys.argv[1]}")
if report["subcellOffsetCells"] != [0.5, 0.75, 0.5]:
    raise SystemExit(f"existing alternate-offset run has the wrong offset: {sys.argv[1]}")
if report["configuration"]["cycles"] != 5:
    raise SystemExit(f"existing alternate-offset run has the wrong cycle count: {sys.argv[1]}")
print(f"reusing passed alternate-offset source run: {sys.argv[1]}")
PY
    continue
  fi
  echo "starting alternate-offset production TRT c${resolution}"
  mkdir -p "$directory"
  started="$(date +%s)"
  "$TOOL" \
    --chord-cells "$resolution" \
    --cycles 5 \
    --leader-phase 0.785 \
    --follower-offset-chords 0,0,-3 \
    --phase-offset 0.25 \
    --subcell-offset-cells "$OFFSET" \
    --archive "$directory" >"$directory/runner.stdout.log"
  python3 - "$report" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
if not report["gates"]["passed"]:
    raise SystemExit(f"alternate-offset source run failed: {sys.argv[1]}")
if report["subcellOffsetCells"] != [0.5, 0.75, 0.5]:
    raise SystemExit(f"alternate-offset run recorded the wrong offset: {sys.argv[1]}")
print(f"c{report['configuration']['chordCells']} passed in {report['runtimeSeconds']:.2f} s")
PY
  echo "completed c${resolution} wall time $(( $(date +%s) - started )) s"
done

if [[ -f "$ARCHIVE/c16-offset2/formation-flight-subcell-source-report.json" \
   && -f "$ARCHIVE/c18-offset2/formation-flight-subcell-source-report.json" \
   && -f "$ARCHIVE/c20-offset2/formation-flight-subcell-source-report.json" ]]; then
  python3 Scripts/analyze-formation-subcell-source-offset2.py
  python3 Scripts/audit-formation-subcell-source-offset2.py
fi
