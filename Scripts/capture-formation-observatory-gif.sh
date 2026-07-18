#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT="${1:-$ROOT/ValidationArtifacts/formation-flight-promotion/c20-best-z3-phase025/formation-flight-report.json}"
OUTPUT="${2:-$ROOT/Docs/Media/formation-flight-observatory.gif}"
SLICE_SOURCE="${3:-$(dirname "$REPORT")/formation-flight-flow-slices}"
SUMMARY="${4:-$ROOT/ValidationArtifacts/formation-flight-promotion/formation-flight-c20-discriminator-summary.json}"
SUBCELL_SUMMARY="${5:-$ROOT/ValidationArtifacts/formation-flight-geometry-subcell-ensemble/formation-flight-geometry-subcell-ensemble-summary.json}"
SOURCE_SUMMARY="${6:-$ROOT/ValidationArtifacts/formation-flight-subcell-source-census/formation-flight-subcell-source-summary.json}"
DOVE_MANIFEST="${7:-$ROOT/ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json}"
GEOMETRY_AUDIT="$ROOT/ValidationArtifacts/formation-flight-observatory-dove-v6.json"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required to encode the formation GIF" >&2
  exit 1
fi

FRAMES="$(mktemp -d "${TMPDIR:-/tmp}/birdflow-formation.XXXXXX")"
cleanup() {
  rm -r "$FRAMES"
}
trap cleanup EXIT

mkdir -p "$(dirname "$OUTPUT")"
cd "$ROOT"
swift build -c release --product birdflow-viewer
CAPTURE_ARGS=(
  --capture-formation-frames "$FRAMES"
  --capture-formation-report "$REPORT"
  --capture-width 1120
  --capture-height 630
  --capture-frames 49
)
if [[ -d "$SLICE_SOURCE" ]]; then
  CAPTURE_ARGS+=(--capture-formation-slice-directory "$SLICE_SOURCE")
else
  CAPTURE_ARGS+=(--capture-formation-slice "$SLICE_SOURCE")
fi
if grep -q '"caseCount"' "$SUMMARY"; then
  CAPTURE_ARGS+=(--capture-formation-summary "$SUMMARY")
else
  CAPTURE_ARGS+=(--capture-formation-discriminator "$SUMMARY")
fi
CAPTURE_ARGS+=(--capture-formation-subcell-summary "$SUBCELL_SUMMARY")
CAPTURE_ARGS+=(--capture-formation-source-summary "$SOURCE_SUMMARY")
CAPTURE_ARGS+=(--capture-formation-dove-manifest "$DOVE_MANIFEST")
.build/release/birdflow-viewer "${CAPTURE_ARGS[@]}"
cp "$FRAMES/presentation-geometry-audit.json" "$GEOMETRY_AUDIT"

ffmpeg -v error -y \
  -framerate 24 \
  -i "$FRAMES/frame-%03d.png" \
  -filter_complex \
  "[0:v]fps=24,scale=1120:630:flags=lanczos,split[a][b];[a]palettegen=max_colors=160:reserve_transparent=0:stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a[v]" \
  -map "[v]" \
  -frames:v 48 \
  -gifflags 0 \
  -loop 0 \
  "$OUTPUT"

DIMENSIONS="$(
  ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height -of csv=s=x:p=0 "$OUTPUT"
)"
FRAME_COUNT="$(
  ffprobe -v error -select_streams v:0 \
    -show_entries stream=nb_frames -of default=nw=1:nk=1 "$OUTPUT"
)"
FIRST_HASH="$(shasum -a 256 "$FRAMES/frame-000.png" | awk '{print $1}')"
LAST_HASH="$(shasum -a 256 "$FRAMES/frame-048.png" | awk '{print $1}')"
BYTES="$(stat -f '%z' "$OUTPUT")"

if [[ "$DIMENSIONS" != "1120x630" || "$FRAME_COUNT" != "48" ]]; then
  echo "unexpected formation GIF contract: ${DIMENSIONS}, ${FRAME_COUNT} frames" >&2
  exit 1
fi
if [[ "$FIRST_HASH" != "$LAST_HASH" ]]; then
  echo "formation GIF endpoint probe is not pixel-seamless" >&2
  exit 1
fi
if (( BYTES >= 10000000 )); then
  echo "formation GIF exceeds the 10 MB budget: $BYTES bytes" >&2
  exit 1
fi

python3 - "$GEOMETRY_AUDIT" <<'PY'
import json, sys
audit = json.load(open(sys.argv[1]))
if not audit["passed"]:
    raise SystemExit("dual-dove presentation audit failed")
if audit["datasetIdentifier"] != "deetjen-ob-2018-12-11-f03-complete-surface-v1":
    raise SystemExit("unexpected dove presentation dataset")
if audit["flyerCount"] != 2 or audit["vertexCountPerFlyer"] != 2157:
    raise SystemExit("unexpected dual-dove topology")
if audit["flyerPairPhaseOffsetCycles"] != 0.25:
    raise SystemExit("unexpected dual-dove phase offset")
if audit["endpointMaximumPositionResidual"] > 1e-7:
    raise SystemExit("dual-dove presentation loop is not seamless")
if audit["flowDisplayMode"] != "nearest-archived-phase-hold":
    raise SystemExit("formation CFD display is not a labeled phase hold")
if audit["capturePhasesWithVisibleFlow"] != audit["capturePhaseCount"]:
    raise SystemExit("formation CFD is not visible at every encoded phase")
if audit["minimumFlowOpacity"] != 1:
    raise SystemExit("formation CFD opacity is not constant")
if audit["tailScale"][1] >= 0.5 * audit["bodyAndWingScale"][1]:
    raise SystemExit("dual-dove presentation tail is not laterally bounded")
if not audit["presentationOnly"] or audit["quantitativeForceAcceptanceReady"]:
    raise SystemExit("dual-dove claim boundary is not fail-closed")
print("dual-dove presentation audit passed")
PY

echo "Formation GIF: $OUTPUT (${DIMENSIONS}, ${FRAME_COUNT} frames, ${BYTES} bytes)"
