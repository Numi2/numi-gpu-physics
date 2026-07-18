#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PREREGISTRATION="ValidationInputs/formation-flight-mechanism-probe-v1.json"
ARCHIVE_ROOT="ValidationArtifacts/formation-flight-mechanism-probe"
RESOLUTIONS="${BIRDFLOW_FORMATION_MECHANISM_RESOLUTIONS:-16 20}"
PHASES="0.785,0.845"

python3 - "$PREREGISTRATION" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

root = Path.cwd()
preregistration = json.load(open(sys.argv[1]))
if not preregistration["preregisteredBeforeMechanismReplayExecution"]:
    raise SystemExit("mechanism experiment was not preregistered")
for locked in preregistration["lockedInputs"]:
    path = root / locked["path"]
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != locked["sha256"]:
        raise SystemExit(f"locked input changed: {locked['path']}")
print("mechanism preregistration and locked inputs verified")
PY

swift build -c release --product birdflow

for resolution in $RESOLUTIONS; do
  case "$resolution" in
    16|20) ;;
    *)
      echo "unsupported mechanism resolution: $resolution" >&2
      exit 1
      ;;
  esac
  reference="ValidationArtifacts/formation-flight-promotion/c${resolution}-best-z3-phase025/formation-flight-report.json"
  archive="$ARCHIVE_ROOT/c${resolution}-best-z3-phase025"
  replay="$archive/formation-flight-field-replay-report.json"
  mechanism="$archive/formation-flight-mechanism-probes.json"
  if [[ -f "$replay" && -f "$mechanism" ]]; then
    python3 - "$replay" "$mechanism" <<'PY'
import json
import sys

replay = json.load(open(sys.argv[1]))
mechanism = json.load(open(sys.argv[2]))
if not replay["gates"]["passed"]:
    raise SystemExit(f"existing mechanism replay failed: {sys.argv[1]}")
if replay["gates"]["maximumRelativeReferenceCoupledHistoryDifference"] > 1e-6:
    raise SystemExit(f"existing mechanism replay misses its reference: {sys.argv[1]}")
if not mechanism["passed"] or len(mechanism["samples"]) != 6:
    raise SystemExit(f"existing mechanism probe is incomplete: {sys.argv[2]}")
print(f"reusing passed mechanism replay: {sys.argv[1]}")
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
    --mechanism-probes \
    --archive "$archive"
done

if [[ -f "$ARCHIVE_ROOT/c16-best-z3-phase025/formation-flight-mechanism-probes.json" \
  && -f "$ARCHIVE_ROOT/c20-best-z3-phase025/formation-flight-mechanism-probes.json" \
  && -x Scripts/analyze-formation-mechanism-probe.py ]]; then
  ./Scripts/analyze-formation-mechanism-probe.py
  ./Scripts/audit-formation-mechanism-probe.py
  ./Scripts/analyze-formation-wake-transport.py
  ./Scripts/audit-formation-wake-transport.py
fi
