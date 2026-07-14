#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift test
python3 Scripts/static-audit.py
python3 Reference/shear_wave_reference.py
python3 Reference/shear_wave_convergence.py

if [[ "$(uname -s)" == "Darwin" ]]; then
  Scripts/check-metal.sh
  swift run birdflow validate shear-wave --json
  swift run birdflow validate moving-wall --json
  swift run birdflow validate sphere --json
  swift run -c release birdflow validate wing --json
else
  echo "Metal compiler and production GPU canonical checks skipped: this host is not macOS."
fi
