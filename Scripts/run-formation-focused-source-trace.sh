#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PREREGISTRATION="ValidationInputs/formation-flight-focused-source-trace-v1.json"
ARCHIVE="ValidationArtifacts/formation-flight-focused-source-trace"
REFERENCE="ValidationArtifacts/formation-flight-subcell-source-census/c18-median-phase/formation-flight-subcell-source-report.json"
ANALYSIS_PYTHON="${BIRDFLOW_ANALYSIS_PYTHON:-python3}"

python3 - "$PREREGISTRATION" <<'PY'
import hashlib
import json
from pathlib import Path
import subprocess
import sys

root = Path.cwd()
prereg = json.load(open(sys.argv[1]))
if not prereg["registeredBeforeTemporalTrace"]:
    raise SystemExit("trace was not registered before the temporal simulation")
head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
if head != prereg["baselineGitCommit"]:
    raise SystemExit(f"baseline commit changed: expected {prereg['baselineGitCommit']}, got {head}")
for group in ("lockedInputs", "lockedImplementation", "lockedAnalysis"):
    for item in prereg[group]:
        actual = hashlib.sha256((root / item["path"]).read_bytes()).hexdigest()
        if actual != item["sha256"]:
            raise SystemExit(f"locked file changed: {item['path']}")
reference = prereg["lockedReference"]
actual = hashlib.sha256((root / reference["path"]).read_bytes()).hexdigest()
if actual != reference["sha256"]:
    raise SystemExit("locked c18 reference report changed")
selector = json.load(open(root / prereg["selectorEvidence"]["summaryPath"]))
selected = selector["selectedTrace"]
for field in ("owner", "component", "directionIndex", "direction", "subcellOffsetCells"):
    if selected[field] != prereg["lockedSelection"][field]:
        raise SystemExit(f"selector mismatch for {field}")
if selector["classification"] != "concentratedStableTraceSelected":
    raise SystemExit("archive-only selector did not authorize a stable trace")
print("focused trace registration, source selection, reference, and hashes verified")
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

rm -rf "$ARCHIVE"
mkdir -p "$ARCHIVE"

swift run -c release \
    --package-path Tools/FormationFocusedSourceTrace \
    FormationFocusedSourceTraceCLI \
    --archive "$ARCHIVE" \
    --reference "$REFERENCE" \
    --chord-cells 18 \
    --cycles 5 \
    --flyer leader \
    --direction-index 5 \
    --follower-offset-chords 0,0,-3 \
    --subcell-offset-cells 0.25,0.25,0.75 \
    --phase-offset 0.25 \
    > "$ARCHIVE/formation-flight-focused-source-trace-cli.json"

"$ANALYSIS_PYTHON" Scripts/analyze-formation-focused-source-trace.py
"$ANALYSIS_PYTHON" Scripts/audit-formation-focused-source-trace.py
