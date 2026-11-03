#!/usr/bin/env bash
# One ronda to film on the emulators: scripts/demo_ronda.py, run with functions/venv's Python
# because the ronda is built by the functions' own code. Its docstring has the scenes and how
# the Android emulator reaches the emulators.
#
#   FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
#       scripts/demo_ronda.sh <email or uid> [--scene ronda|rain|handoff|newcomer|attendance]
#
# Needs functions/venv (docs/STACK.md § Native and project checklist).
set -euo pipefail
cd "$(dirname "$0")/.."
exec functions/venv/bin/python scripts/demo_ronda.py "$@"
