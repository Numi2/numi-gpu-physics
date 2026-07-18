#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PREREGISTRATION="ValidationInputs/formation-flight-link-sampling-subdecomposition-v1.json"

python3 - "$PREREGISTRATION" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

root = Path.cwd()
preregistration = json.load(open(sys.argv[1]))
if not preregistration["preregisteredBeforeSubdecompositionExecution"]:
    raise SystemExit("link-sampling subdecomposition was not preregistered")
for group in ("lockedInputs", "lockedAnalysis"):
    for locked in preregistration[group]:
        actual = hashlib.sha256((root / locked["path"]).read_bytes()).hexdigest()
        if actual != locked["sha256"]:
            raise SystemExit(f"locked file changed: {locked['path']}")
print("link-sampling subdecomposition preregistration verified")
PY

python3 Scripts/analyze-formation-link-sampling-subdecomposition.py
python3 Scripts/audit-formation-link-sampling-subdecomposition.py
