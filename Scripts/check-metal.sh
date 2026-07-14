#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOLVER_SOURCE="$ROOT/Sources/BirdFlowMetal/Metal/BirdFlow.metal"
VISUALIZATION_SOURCE="$ROOT/Sources/BirdFlowVisualization/Metal/Visualization.metal"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "check-metal.sh requires macOS and Apple's xcrun Metal toolchain." >&2
  exit 2
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun was not found. Install the Xcode command-line tools." >&2
  exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for entry in \
  "BirdFlow:$SOLVER_SOURCE" \
  "BirdFlowVisualization:$VISUALIZATION_SOURCE"; do
  name="${entry%%:*}"
  source="${entry#*:}"
  xcrun -sdk macosx metal -std=metal3.1 -Wall -Wextra \
    -c "$source" -o "$TMP/$name.air"
  xcrun -sdk macosx metallib "$TMP/$name.air" \
    -o "$TMP/$name.metallib"
  echo "Metal source compiled successfully: $source"
done
