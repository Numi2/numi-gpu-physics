#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/ValidationArtifacts/deetjen-dove-through-flight-v1.json}"

cd "$ROOT"
swift build -c release --product birdflow
.build/release/birdflow simulate deetjen-dove \
  --input "$ROOT/ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json" \
  --force-target "$ROOT/ValidationInputs/deetjen-ob-f03-force-v1.json" \
  --archive "$OUTPUT"

python3 - "$OUTPUT" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    report = json.load(stream)

required = {
    "passed": True,
    "fullSourceTimelineCompleted": True,
    "sourceTranslationPreserved": True,
    "prescribedMotion": True,
}
for key, expected in required.items():
    if report.get(key) != expected:
        raise SystemExit(f"through-flight contract failed: {key}")
if report.get("sourceFrameCount") != 144:
    raise SystemExit("through-flight contract failed: sourceFrameCount")
pilot = report.get("pilot", {})
plan = pilot.get("plan", {})
if pilot.get("completedFluidSteps") != plan.get("totalFluidSteps"):
    raise SystemExit("through-flight contract failed: incomplete Metal steps")
print(f"verified Deetjen through-flight artifact: {sys.argv[1]}")
PY
