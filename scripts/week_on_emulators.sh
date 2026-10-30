#!/usr/bin/env bash
# A test ronda's first week on the Firestore emulator (#28's and #48's done-when): the RSVP push,
# the answers, the bench filling a seat, attendance and the ¿seguimos? result, through
# functions/tests/test_week.py with Firestore's own transactions. No model, no FCM: the model is
# scripted and the sender a stand-in. The project is a demo one, so nothing real is touched.
#
#   scripts/week_on_emulators.sh
#
# Needs functions/venv (docs/STACK.md) and the Firebase CLI. It starts and stops its own
# emulator on firebase.json's Firestore port, so nothing else may hold that port meanwhile.
set -euo pipefail
cd "$(dirname "$0")/.."
firebase emulators:exec --only firestore --project demo-ronda-bench \
  "cd functions && venv/bin/pytest -q -p no:cacheprovider tests/test_week.py"
