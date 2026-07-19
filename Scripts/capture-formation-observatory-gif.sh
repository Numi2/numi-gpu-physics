#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT="${1:-$ROOT/ValidationArtifacts/formation-flight-promotion/c20-best-z3-phase025/formation-flight-report.json}"
DEFAULT_OUTPUT="$ROOT/Docs/Media/formation-flight-observatory.gif"
OUTPUT="${2:-$DEFAULT_OUTPUT}"
SLICE_SOURCE="${3:-$(dirname "$REPORT")/formation-flight-flow-slices}"
SUMMARY="${4:-$ROOT/ValidationArtifacts/formation-flight-promotion/formation-flight-c20-discriminator-summary.json}"
SUBCELL_SUMMARY="${5:-$ROOT/ValidationArtifacts/formation-flight-geometry-subcell-ensemble/formation-flight-geometry-subcell-ensemble-summary.json}"
SOURCE_SUMMARY="${6:-$ROOT/ValidationArtifacts/formation-flight-subcell-source-census/formation-flight-subcell-source-summary.json}"
DOVE_MANIFEST="${7:-$ROOT/ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json}"
FOCUSED_SOURCE_TRACE="${8:-$ROOT/ValidationArtifacts/formation-flight-focused-source-trace/formation-flight-focused-source-trace-report.json}"
GEOMETRY_AUDIT="$ROOT/ValidationArtifacts/formation-flight-observatory-dove-v10.json"
V6_ARCHIVE="$ROOT/Docs/Media/Progress/2026-07-18-v6-dual-dove-continuous-cfd.gif"
V6_SHA256="54255ff84b855f2124ec0d6fbff2449bab740c6d9f61cef70c1ba89ea5298b61"
V7_ARCHIVE="$ROOT/Docs/Media/Progress/2026-07-18-v7-cinematic-wake-bridge.gif"
V7_SHA256="1d0dc0835512739e54e6f67352a76ed7de960ef913d38350e3744619d8800e09"
V8_ARCHIVE="$ROOT/Docs/Media/Progress/2026-07-18-v8-figure-eight-camera.gif"
V8_SHA256="f4af3b62318d0fffd1d2e41fa157cf12e3a054400ba7ba6d4e9973448bde3564"
V9_ARCHIVE="$ROOT/Docs/Media/Progress/2026-07-19-v9-seamless-field-figure-eight.gif"
V9_SHA256="b17a669ee923ad17281316577c28c704b4ae27d86f912d59b5ec29f533cbb65e"
V10_MANIFEST="$ROOT/ValidationArtifacts/formation-flight-observatory-visual-v10.json"

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
if [[ "$OUTPUT" == "$DEFAULT_OUTPUT" ]]; then
  CURRENT_SHA="$(shasum -a 256 "$DEFAULT_OUTPUT" | awk '{print $1}')"
  LOCKED_V10_SHA=""
  if [[ -f "$V10_MANIFEST" ]]; then
    LOCKED_V10_SHA="$(python3 - "$V10_MANIFEST" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))["output"]["sha256"])
PY
)"
  fi
  if [[ "$CURRENT_SHA" != "$V9_SHA256" && "$CURRENT_SHA" != "$LOCKED_V10_SHA" ]]; then
    echo "current Formation GIF is neither the locked V9 predecessor nor V10" >&2
    exit 1
  fi
  if [[ ! -f "$V6_ARCHIVE" ]] \
    || [[ "$(shasum -a 256 "$V6_ARCHIVE" | awk '{print $1}')" != "$V6_SHA256" ]]; then
    echo "V6 progress archive is missing or invalid" >&2
    exit 1
  fi
  if [[ -f "$V7_ARCHIVE" ]]; then
    ARCHIVE_SHA="$(shasum -a 256 "$V7_ARCHIVE" | awk '{print $1}')"
    if [[ "$ARCHIVE_SHA" != "$V7_SHA256" ]]; then
      echo "V7 progress archive does not match its lock" >&2
      exit 1
    fi
  else
    echo "V7 progress archive is missing" >&2
    exit 1
  fi
  if [[ -f "$V8_ARCHIVE" ]]; then
    ARCHIVE_SHA="$(shasum -a 256 "$V8_ARCHIVE" | awk '{print $1}')"
    if [[ "$ARCHIVE_SHA" != "$V8_SHA256" ]]; then
      echo "V8 progress archive does not match the locked predecessor" >&2
      exit 1
    fi
  else
    if [[ "$CURRENT_SHA" != "$V8_SHA256" ]]; then
      echo "V8 progress archive is missing and cannot be recovered from V9" >&2
      exit 1
    fi
    cp "$DEFAULT_OUTPUT" "$V8_ARCHIVE"
  fi
  if [[ -f "$V9_ARCHIVE" ]]; then
    ARCHIVE_SHA="$(shasum -a 256 "$V9_ARCHIVE" | awk '{print $1}')"
    if [[ "$ARCHIVE_SHA" != "$V9_SHA256" ]]; then
      echo "V9 progress archive does not match the locked predecessor" >&2
      exit 1
    fi
  else
    if [[ "$CURRENT_SHA" != "$V9_SHA256" ]]; then
      echo "V9 progress archive is missing and cannot be recovered from V10" >&2
      exit 1
    fi
    cp "$DEFAULT_OUTPUT" "$V9_ARCHIVE"
  fi
fi
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
CAPTURE_ARGS+=(--capture-formation-focused-source-trace "$FOCUSED_SOURCE_TRACE")
CAPTURE_ARGS+=(--capture-formation-dove-manifest "$DOVE_MANIFEST")
.build/release/birdflow-viewer "${CAPTURE_ARGS[@]}"
cp "$FRAMES/presentation-geometry-audit.json" "$GEOMETRY_AUDIT"

ffmpeg -v error -y \
  -framerate 24 \
  -i "$FRAMES/frame-%03d.png" \
  -filter_complex \
  "[0:v]fps=24,scale=1120:630:flags=lanczos,split[a][b];[a]palettegen=max_colors=192:reserve_transparent=0:stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a[v]" \
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
if audit["flowDisplayMode"] != "cyclic-linear-interpolation-of-archived-c20-phases":
    raise SystemExit("formation CFD display is not the locked cyclic phase interpolation")
if audit["capturePhasesWithVisibleFlow"] != audit["capturePhaseCount"]:
    raise SystemExit("formation CFD is not visible at every encoded phase")
if audit["minimumFlowOpacity"] != 1:
    raise SystemExit("formation CFD opacity is not constant")
if audit["schemaVersion"] != 6:
    raise SystemExit("formation presentation audit schema changed")
if audit["flowSpatialFilterMode"] != "gaussian-radius4-sigma2-with-solid-gap-fill-presentation-only":
    raise SystemExit("formation flow spatial presentation filter changed")
if audit["flowOpacityMode"] != "joint-vorticity-and-vertical-velocity-signal":
    raise SystemExit("formation flow opacity signal contract changed")
if audit["minimumDisplayedSignalOpacity"] != 0.025:
    raise SystemExit("formation flow signal floor changed")
if audit["wakeBridgeMode"] != "archived-c20-vorticity-ridge+c18-q5-luminance":
    raise SystemExit("formation wake bridge does not preserve its two-source evidence contract")
if audit["wakeIntersectionMarkerMode"] != "presentation-phase-ring-at-follower-plane":
    raise SystemExit("formation wake intersection marker contract changed")
if audit["latticeBoltzmannDisplayMode"] != "presentation-only-d3q19-collision-streaming-lens":
    raise SystemExit("formation D3Q19 presentation lens changed")
if [audit["latticeDirectionCount"], audit["latticeRestPopulationCount"], audit["latticeAxisDirectionCount"], audit["latticeFaceDiagonalDirectionCount"]] != [19, 1, 6, 12]:
    raise SystemExit("formation D3Q19 population topology changed")
if audit["focusedMomentumExchangeDirectionIndex"] != 5 or audit["focusedMomentumExchangeDirection"] != [0, 0, 1]:
    raise SystemExit("formation focused q5 momentum-exchange direction changed")
if audit["trailDrawCallMode"] != "single-degenerate-strip-batch":
    raise SystemExit("formation wake draw-call batching changed")
if audit["postProcessingMode"] != "rgba16f-half-resolution-25-tap-bloom-highlight-rolloff":
    raise SystemExit("formation HDR finishing path changed")
if audit["focusedSourceTraceSampleCount"] != 4820 or audit["focusedSourceTraceDirectionIndex"] != 5:
    raise SystemExit("formation wake bridge is not locked to the complete leader-q5 trace")
if audit["wakeBridgePhaseCount"] != audit["capturePhaseCount"]:
    raise SystemExit("formation wake bridge is not present at every encoded phase")
if audit["overlayMode"] != "none-cinematic":
    raise SystemExit("formation GIF contains a presentation overlay")
if audit["cameraCompositionMode"] != "spherical-figure-eight-dual-dove-wake-bridge":
    raise SystemExit("formation GIF camera composition contract changed")
if audit["cameraYawAmplitudeRadians"] != 0.34:
    raise SystemExit("formation GIF yaw amplitude changed")
if audit["cameraPitchAmplitudeRadians"] != 0.1:
    raise SystemExit("formation GIF pitch amplitude changed")
if audit["cameraDistanceAmplitudeChords"] != 0.1:
    raise SystemExit("formation GIF distance amplitude changed")
if audit["cameraEndpointParameterResidual"] > 1e-7:
    raise SystemExit("formation figure-eight camera path is not seamless")
if audit["tailScale"][1] >= 0.5 * audit["bodyAndWingScale"][1]:
    raise SystemExit("dual-dove presentation tail is not laterally bounded")
if not audit["presentationOnly"] or audit["quantitativeForceAcceptanceReady"]:
    raise SystemExit("dual-dove claim boundary is not fail-closed")
print("dual-dove presentation audit passed")
PY

echo "Formation GIF: $OUTPUT (${DIMENSIONS}, ${FRAME_COUNT} frames, ${BYTES} bytes)"
