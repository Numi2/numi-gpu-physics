#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PREREGISTRATION="ValidationInputs/formation-flight-geometry-subcell-ensemble-v1.json"
ARCHIVE="ValidationArtifacts/formation-flight-geometry-subcell-ensemble"
REPORT="$ARCHIVE/formation-flight-geometry-subcell-ensemble.json"
STDOUT_COPY="$ARCHIVE/formation-flight-geometry-subcell-ensemble.stdout.json"

python3 - "$PREREGISTRATION" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

root = Path.cwd()
preregistration = json.load(open(sys.argv[1]))
if not preregistration["preregisteredBeforeEnsembleExecution"]:
    raise SystemExit("formation subcell ensemble was not preregistered")
for group in ("lockedInputs", "lockedImplementation", "lockedAnalysis"):
    for locked in preregistration[group]:
        actual = hashlib.sha256((root / locked["path"]).read_bytes()).hexdigest()
        if actual != locked["sha256"]:
            raise SystemExit(f"locked file changed: {locked['path']}")
print("formation subcell ensemble preregistration verified")
PY

mkdir -p "$ARCHIVE"
swift run -c release \
    --package-path Tools/FormationGeometrySubcell \
    FormationGeometrySubcellCLI \
    --divisions 4 \
    --output "$REPORT" \
    > "$STDOUT_COPY"

python3 - "$REPORT" "$STDOUT_COPY" <<'PY'
import json
import sys

with open(sys.argv[1]) as canonical, open(sys.argv[2]) as stdout_copy:
    if json.load(canonical) != json.load(stdout_copy):
        raise SystemExit("canonical and stdout subcell reports differ")
print("canonical and stdout subcell reports are semantically identical")
PY

python3 Scripts/analyze-formation-geometry-subcell-ensemble.py
python3 Scripts/audit-formation-geometry-subcell-ensemble.py
