#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/Docs/Media/deetjen-through-flight-observatory.mp4}"
POSTER="${2:-$ROOT/Docs/Media/deetjen-through-flight-observatory.png}"
AUDIT="${3:-$ROOT/ValidationArtifacts/deetjen-through-flight-observatory-v1.json}"
REPORT="$ROOT/ValidationArtifacts/deetjen-dove-through-flight-v1.json"
MANIFEST="$ROOT/ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required to encode the through-flight observatory" >&2
  exit 1
fi
if ! command -v ffprobe >/dev/null 2>&1; then
  echo "ffprobe is required to verify the through-flight observatory" >&2
  exit 1
fi

FRAMES="$(mktemp -d "${TMPDIR:-/tmp}/birdflow-deetjen-flight.XXXXXX")"
cleanup() {
  rm -r "$FRAMES"
}
trap cleanup EXIT

mkdir -p "$(dirname "$OUTPUT")" "$(dirname "$POSTER")" "$(dirname "$AUDIT")"
cd "$ROOT"
swift build -c release --product birdflow-viewer
.build/release/birdflow-viewer \
  --capture-deetjen-through-flight "$FRAMES" \
  --capture-deetjen-manifest "$MANIFEST" \
  --capture-deetjen-report "$REPORT" \
  --capture-width 1120 \
  --capture-height 630 \
  --capture-frames 48

ffmpeg -v error -y \
  -framerate 24 \
  -i "$FRAMES/frame-%03d.png" \
  -c:v libx264 \
  -preset slow \
  -crf 17 \
  -pix_fmt yuv420p \
  -movflags +faststart \
  "$OUTPUT"
cp "$FRAMES/frame-032.png" "$POSTER"
cp "$FRAMES/observatory-audit.json" "$AUDIT"

DIMENSIONS="$(
  ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height -of csv=s=x:p=0 "$OUTPUT"
)"
FRAME_COUNT="$(
  ffprobe -v error -count_frames -select_streams v:0 \
    -show_entries stream=nb_read_frames -of default=nw=1:nk=1 "$OUTPUT"
)"
FIRST_HASH="$(shasum -a 256 "$FRAMES/frame-000.png" | awk '{print $1}')"
LAST_HASH="$(shasum -a 256 "$FRAMES/frame-047.png" | awk '{print $1}')"

if [[ "$DIMENSIONS" != "1120x630" || "$FRAME_COUNT" != "48" ]]; then
  echo "unexpected observatory video contract: ${DIMENSIONS}, ${FRAME_COUNT} frames" >&2
  exit 1
fi
if [[ "$FIRST_HASH" == "$LAST_HASH" ]]; then
  echo "through-flight endpoints are visually identical; translation was lost" >&2
  exit 1
fi

python3 - "$AUDIT" "$REPORT" <<'PY'
import hashlib
import json
import pathlib
import sys

audit_path = pathlib.Path(sys.argv[1])
report_path = pathlib.Path(sys.argv[2])
audit = json.loads(audit_path.read_text())
report = json.loads(report_path.read_text())
expected = {
    "passed": True,
    "rawLaboratoryFrameGeometry": True,
    "bodyFollowingCamera": True,
    "prescribedMotion": True,
    "fullSourceTimelineCompleted": True,
    "sourceFrameCount": 144,
    "trajectorySampleCount": 144,
    "renderedFrameCount": 48,
    "wakeFieldArchivePassed": True,
    "wakeSliceCount": 26,
    "wakeRenderedFrameCount": 47,
}
for key, value in expected.items():
    if audit.get(key) != value:
        raise SystemExit(f"through-flight observatory audit failed: {key}")
if audit.get("throughFlightReportSchemaVersion") != 3:
    raise SystemExit("through-flight observatory did not consume schema-3 evidence")
if audit.get("maximumTrajectoryCenterResidualMeters", 1) > 1e-7:
    raise SystemExit("through-flight observatory trajectory drifted from source geometry")
if audit.get("completedFluidSteps") != audit.get("plannedFluidSteps"):
    raise SystemExit("through-flight observatory consumed an incomplete CFD run")
if audit.get("minimumSampledPopulation", 0) <= 0:
    raise SystemExit("through-flight observatory consumed a non-positive CFD state")
digest = hashlib.sha256(report_path.read_bytes()).hexdigest()
if audit.get("throughFlightReportSHA256") != digest:
    raise SystemExit("through-flight observatory report hash mismatch")
if len(report.get("bodyTrajectorySamples", [])) != 144:
    raise SystemExit("through-flight report does not archive every body trajectory frame")
if report.get("wakeFieldArchivePassed") is not True \
        or len(report.get("wakeSlices", [])) != 26:
    raise SystemExit("through-flight report does not archive the qualified wake slices")
if audit.get("wakeVorticityDisplayScalePerSecond", 0) <= 0 \
        or audit.get("wakePositiveQDisplayScalePerSecondSquared", 0) <= 0:
    raise SystemExit("through-flight observatory wake display scale is invalid")
print(f"verified Deetjen through-flight observatory: {audit_path}")
PY

BYTES="$(stat -f '%z' "$OUTPUT")"
SHA256="$(shasum -a 256 "$OUTPUT" | awk '{print $1}')"
echo "Deetjen observatory: $OUTPUT (${DIMENSIONS}, ${FRAME_COUNT} frames, ${BYTES} bytes, sha256=${SHA256})"
