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
  --capture-width 896 \
  --capture-height 504 \
  --capture-frames 40 \
  --capture-pre-roll 384

ffmpeg -v error -y \
  -framerate 20 \
  -i "$FRAMES/frame-%03d.png" \
  -filter_complex \
  "[0:v]fps=20,scale=896:504:flags=lanczos,split[a][b];[a]palettegen=max_colors=160:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle[v]" \
  -map "[v]" \
  -loop 0 \
  "$OUTPUT"

echo "README GIF: $OUTPUT"
