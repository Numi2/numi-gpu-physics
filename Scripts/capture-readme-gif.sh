#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/Docs/Media/birdflow-metal-native-viewer.gif}"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required to encode the README GIF" >&2
  exit 1
fi

FRAMES="$(mktemp -d "${TMPDIR:-/tmp}/birdflow-readme.XXXXXX")"
cleanup() {
  rm -r "$FRAMES"
}
trap cleanup EXIT

mkdir -p "$(dirname "$OUTPUT")"
cd "$ROOT"

swift build -c release --product birdflow-viewer
.build/release/birdflow-viewer \
  --capture-readme-frames "$FRAMES" \
  --capture-width 1120 \
  --capture-height 630 \
  --capture-frames 72 \
  --capture-dove-manifest \
    "$ROOT/ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json" \
  --capture-dove-pilot \
    "$ROOT/ValidationArtifacts/deetjen-dove-collision-extended-pilot.json"

ffmpeg -v error -y \
  -framerate 24 \
  -i "$FRAMES/frame-%03d.png" \
  -filter_complex \
  "[0:v]fps=24,scale=1120:630:flags=lanczos,split[a][b];[a]palettegen=max_colors=192:reserve_transparent=0:stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a[v]" \
  -map "[v]" \
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
FRAME_RATE="$(
  ffprobe -v error -select_streams v:0 \
    -show_entries stream=r_frame_rate -of default=nw=1:nk=1 "$OUTPUT"
)"
BYTES="$(stat -f '%z' "$OUTPUT")"
SEAM_HASHES="$(
  ffmpeg -v error -i "$OUTPUT" \
    -vf "select='eq(n,0)+eq(n,71)'" -vsync 0 -f framemd5 - \
    | awk -F',' '!/^#/ {gsub(/ /, "", $6); print $6}'
)"
FIRST_HASH="$(printf '%s\n' "$SEAM_HASHES" | sed -n '1p')"
LAST_HASH="$(printf '%s\n' "$SEAM_HASHES" | sed -n '2p')"

if [[ "$DIMENSIONS" != "1120x630" || "$FRAME_COUNT" != "72" \
  || "$FRAME_RATE" != "24/1" ]]; then
  echo "unexpected README GIF contract: ${DIMENSIONS}, ${FRAME_COUNT} frames, ${FRAME_RATE}" >&2
  exit 1
fi
if (( BYTES >= 10000000 )); then
  echo "README GIF exceeds the 10 MB presentation budget: $BYTES bytes" >&2
  exit 1
fi
if [[ -z "$FIRST_HASH" || "$FIRST_HASH" != "$LAST_HASH" ]]; then
  echo "README GIF is not pixel-seamless at the loop boundary" >&2
  exit 1
fi

echo "README GIF: $OUTPUT (${DIMENSIONS}, ${FRAME_COUNT} frames, ${BYTES} bytes)"
