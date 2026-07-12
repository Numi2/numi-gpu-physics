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
else
  echo "Metal compiler check skipped: this host is not macOS."
fi
