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
if report.get("schemaVersion") != 3:
    raise SystemExit("through-flight contract failed: schemaVersion")
trajectory = report.get("bodyTrajectorySamples", [])
if len(trajectory) != 144:
    raise SystemExit("through-flight contract failed: bodyTrajectorySamples")
if trajectory[0].get("sourceFrameIndex") != 0 \
        or trajectory[-1].get("sourceFrameIndex") != 143:
    raise SystemExit("through-flight contract failed: trajectory endpoints")
if any(
    right["sourceTimeSeconds"] <= left["sourceTimeSeconds"]
    or right["cumulativeTravelMeters"] < left["cumulativeTravelMeters"]
    for left, right in zip(trajectory, trajectory[1:])
):
    raise SystemExit("through-flight contract failed: trajectory monotonicity")
if report.get("wakeFieldArchivePassed") is not True:
    raise SystemExit("through-flight contract failed: wakeFieldArchivePassed")
wake = report.get("wakeSlices", [])
if len(wake) != 26:
    raise SystemExit("through-flight contract failed: wakeSlices")
if wake[0].get("sourceFrameIndex") != 1 \
        or wake[-1].get("sourceFrameIndex") != 143:
    raise SystemExit("through-flight contract failed: wake endpoints")
if report.get("wakeVorticityDisplayScalePerSecond", 0) <= 0 \
        or report.get("wakePositiveQDisplayScalePerSecondSquared", 0) <= 0:
    raise SystemExit("through-flight contract failed: wake display scales")
if any(
    item.get("validCellCount", 0) <= 0
    or item.get("maximumAbsoluteStreamwiseVorticityPerSecond", 0) <= 0
    or item.get("maximumPositiveQCriterionPerSecondSquared", 0) <= 0
    for item in wake
):
    raise SystemExit("through-flight contract failed: wake slice diagnostics")
pilot = report.get("pilot", {})
plan = pilot.get("plan", {})
if pilot.get("completedFluidSteps") != plan.get("totalFluidSteps"):
    raise SystemExit("through-flight contract failed: incomplete Metal steps")
print(f"verified Deetjen through-flight artifact: {sys.argv[1]}")
PY
