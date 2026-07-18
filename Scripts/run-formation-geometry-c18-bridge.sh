#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PREREGISTRATION="ValidationInputs/formation-flight-geometry-c18-bridge-v1.json"
ARCHIVE="ValidationArtifacts/formation-flight-geometry-c18-bridge"
REPORT="$ARCHIVE/formation-flight-geometry-census.json"

python3 - "$PREREGISTRATION" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

root = Path.cwd()
preregistration = json.load(open(sys.argv[1]))
if not preregistration["preregisteredBeforeC18Execution"]:
    raise SystemExit("c18 geometry bridge was not preregistered")
for group in ("lockedInputs", "lockedImplementation", "lockedAnalysis"):
    for locked in preregistration[group]:
        actual = hashlib.sha256((root / locked["path"]).read_bytes()).hexdigest()
        if actual != locked["sha256"]:
            raise SystemExit(f"locked file changed: {locked['path']}")
print("c18 geometry bridge preregistration verified")
PY

mkdir -p "$ARCHIVE"
swift run -c release birdflow-formation-geometry \
    --chord-cells 16,18,20 \
    --leader-phase 0.785 \
    --offset-z -3 \
    --phase-offset 0.25 \
    --output "$REPORT" \
    > "$ARCHIVE/formation-flight-geometry-census.stdout.json"

python3 - "$REPORT" "$ARCHIVE/formation-flight-geometry-census.stdout.json" <<'PY'
import json
import sys

with open(sys.argv[1]) as canonical, open(sys.argv[2]) as stdout_copy:
    if json.load(canonical) != json.load(stdout_copy):
        raise SystemExit("canonical and stdout geometry reports differ")
print("canonical and stdout geometry reports are semantically identical")
PY
python3 Scripts/analyze-formation-geometry-c18-bridge.py
python3 Scripts/audit-formation-geometry-c18-bridge.py
