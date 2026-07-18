#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PREREGISTRATION="ValidationInputs/formation-flight-source-residual-covariance-v1.json"
ANALYSIS_PYTHON="${BIRDFLOW_ANALYSIS_PYTHON:-python3}"

python3 - "$PREREGISTRATION" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

root = Path.cwd()
prereg = json.load(open(sys.argv[1]))
if not prereg["registeredBeforeResidualSelection"]:
    raise SystemExit("residual selector was not registered before detailed analysis")
for group in ("lockedInputs", "lockedAnalysis"):
    for item in prereg[group]:
        actual = hashlib.sha256((root / item["path"]).read_bytes()).hexdigest()
        if actual != item["sha256"]:
            raise SystemExit(f"locked file changed: {item['path']}")
print("archive-only residual selector registration and hashes verified")
PY

"$ANALYSIS_PYTHON" - <<'PY'
import matplotlib
import numpy

if numpy.__version__ != "2.5.1" or matplotlib.__version__ != "3.11.1":
    raise SystemExit(
        "analysis environment mismatch: expected numpy 2.5.1 and matplotlib 3.11.1"
    )
print("analysis environment verified: numpy 2.5.1, matplotlib 3.11.1")
PY

"$ANALYSIS_PYTHON" Scripts/analyze-formation-source-residual-covariance.py
"$ANALYSIS_PYTHON" Scripts/audit-formation-source-residual-covariance.py
