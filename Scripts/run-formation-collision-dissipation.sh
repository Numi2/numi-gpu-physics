#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PREREGISTRATION="ValidationInputs/formation-flight-collision-dissipation-discriminator-v1.json"
OUTPUT_ROOT="ValidationArtifacts/formation-flight-collision-dissipation"
OPERATOR="positivity-preserving-recursive-regularized-bgk"
PHASES="0.805,0.815,0.825,0.835,0.845"

python3 - "$PREREGISTRATION" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

root = Path.cwd()
prereg = json.load(open(sys.argv[1]))
if not prereg["preregisteredBeforeCandidateExecution"]:
    raise SystemExit("collision discriminator was not preregistered")
for locked in prereg["lockedInputs"]:
    actual = hashlib.sha256((root / locked["path"]).read_bytes()).hexdigest()
    if actual != locked["sha256"]:
        raise SystemExit(f"locked input changed: {locked['path']}")
source = json.load(open(root / prereg["lockedInputs"][0]["path"]))
if source["classification"] != prereg["requiredSourceClassification"]:
    raise SystemExit("source classification does not authorize collision screen")
print("collision discriminator preregistration and locked inputs verified")
PY

swift build -c release --product birdflow

run_candidate() {
  local resolution="$1"
  local archive="$OUTPUT_ROOT/c${resolution}-rr3"
  local report="$archive/formation-flight-collision-diagnostic-report.json"
  if [[ -f "$report" ]]; then
    python3 - "$report" "$resolution" "$OPERATOR" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1]))
if report["collisionOperator"] != sys.argv[3]:
    raise SystemExit(f"existing candidate uses wrong operator: {sys.argv[1]}")
if report["configuration"]["chordCells"] != int(sys.argv[2]) or report["configuration"]["cycles"] != 5:
    raise SystemExit(f"existing candidate uses wrong configuration: {sys.argv[1]}")
if not report["gates"]["passed"]:
    raise SystemExit(f"existing candidate failed: {sys.argv[1]}")
print(f"reusing passed candidate: {sys.argv[1]}")
PY
    return
  fi
  .build/release/birdflow validate formation-flight \
    --chord-cells "$resolution" \
    --cycles 5 \
    --offset-z -3 \
    --phase-offset 0.25 \
    --field-phases "$PHASES" \
    --collision-operator "$OPERATOR" \
    --archive "$archive"
}

run_candidate 16
./Scripts/analyze-formation-collision-dissipation.py
./Scripts/audit-formation-collision-dissipation.py

if python3 - "$OUTPUT_ROOT/formation-flight-collision-dissipation-summary.json" <<'PY'
import json
import sys

summary = json.load(open(sys.argv[1]))
raise SystemExit(0 if summary["promotion"]["c20CandidateAuthorized"] else 1)
PY
then
  run_candidate 20
  ./Scripts/analyze-formation-collision-dissipation.py
  ./Scripts/audit-formation-collision-dissipation.py
else
  echo "c20 RR3 allocation stopped by the preregistered c16 screen"
fi
