#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PREREGISTRATION="ValidationInputs/formation-flight-boundary-source-census-v1.json"
ARCHIVE_ROOT="ValidationArtifacts/formation-flight-boundary-source-census"
RESOLUTIONS="${BIRDFLOW_FORMATION_BOUNDARY_SOURCE_RESOLUTIONS:-16 20}"
PHASES="0.785,0.845"

python3 - "$PREREGISTRATION" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

root = Path.cwd()
preregistration = json.load(open(sys.argv[1]))
if not preregistration["preregisteredBeforeBoundarySourceReplayExecution"]:
    raise SystemExit("boundary-source experiment was not preregistered")
for group in ("lockedInputs", "lockedImplementation", "lockedAnalysis"):
    for locked in preregistration[group]:
        path = root / locked["path"]
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != locked["sha256"]:
            raise SystemExit(f"locked file changed: {locked['path']}")
for locked in preregistration["qualificationAmendment"]["failedSmokeArtifacts"]:
    path = root / locked["path"]
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != locked["sha256"]:
        raise SystemExit(f"qualification evidence changed: {locked['path']}")
print("boundary-source preregistration, inputs, solver, and analysis verified")
PY

python3 Scripts/static-audit.py
swift build -c release --product birdflow

smoke_reference="ValidationArtifacts/formation-flight-scout-v1/y0-z3-phase0p25/formation-flight-report.json"
smoke_archive="$ARCHIVE_ROOT/c8-instrumentation-smoke"
smoke_replay="$smoke_archive/formation-flight-field-replay-report.json"
smoke_census="$smoke_archive/formation-flight-boundary-source-census.json"
if [[ -f "$smoke_replay" && -f "$smoke_census" ]]; then
  python3 - "$smoke_replay" "$smoke_census" <<'PY'
import json
import sys
replay, census = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
if not replay["gates"]["passed"] or not census["passed"]:
    raise SystemExit("existing c8 boundary-source smoke failed")
if replay["gates"]["maximumRelativeReferenceCoupledHistoryDifference"] > 1e-6:
    raise SystemExit("existing c8 boundary-source smoke perturbed the reference")
if len(census["samples"]) != 4:
    raise SystemExit("existing c8 boundary-source smoke is incomplete")
print("reusing passed c8 boundary-source instrumentation smoke")
PY
else
  .build/release/birdflow validate formation-flight \
    --chord-cells 8 \
    --cycles 3 \
    --offset-z -3 \
    --phase-offset 0.25 \
    --field-phases "$PHASES" \
    --field-replay-reference "$smoke_reference" \
    --boundary-source-census \
    --archive "$smoke_archive"
fi

for resolution in $RESOLUTIONS; do
  case "$resolution" in
    16|20) ;;
    *)
      echo "unsupported boundary-source resolution: $resolution" >&2
      exit 1
      ;;
  esac
  reference="ValidationArtifacts/formation-flight-promotion/c${resolution}-best-z3-phase025/formation-flight-report.json"
  archive="$ARCHIVE_ROOT/c${resolution}-best-z3-phase025"
  replay="$archive/formation-flight-field-replay-report.json"
  census="$archive/formation-flight-boundary-source-census.json"
  if [[ -f "$replay" && -f "$census" ]]; then
    python3 - "$replay" "$census" <<'PY'
import json
import sys
replay, census = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
if not replay["gates"]["passed"] or not census["passed"]:
    raise SystemExit(f"existing boundary-source replay failed: {sys.argv[1]}")
if replay["gates"]["maximumRelativeReferenceCoupledHistoryDifference"] > 1e-6:
    raise SystemExit(f"existing boundary-source replay misses reference: {sys.argv[1]}")
if len(census["samples"]) != 4:
    raise SystemExit(f"existing boundary-source census is incomplete: {sys.argv[2]}")
print(f"reusing passed boundary-source replay: {sys.argv[1]}")
PY
    continue
  fi
  .build/release/birdflow validate formation-flight \
    --chord-cells "$resolution" \
    --cycles 5 \
    --offset-z -3 \
    --phase-offset 0.25 \
    --field-phases "$PHASES" \
    --field-replay-reference "$reference" \
    --boundary-source-census \
    --archive "$archive"
done

if [[ -f "$ARCHIVE_ROOT/c16-best-z3-phase025/formation-flight-boundary-source-census.json" \
  && -f "$ARCHIVE_ROOT/c20-best-z3-phase025/formation-flight-boundary-source-census.json" ]]; then
  python3 Scripts/analyze-formation-boundary-source-census.py
  python3 Scripts/audit-formation-boundary-source-census.py
fi
