# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["firebase-admin>=7,<8"]
# ///
"""Load the invented demo seat facts into the Firestore emulator.

    FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 uv run --python 3.13 scripts/seed/seed_seat_facts.py

Writes one `seat_facts/{seatId}` document per seat in data/demo/invented_seat_facts.json,
replacing any document with the same id. It refuses to run without FIRESTORE_EMULATOR_HOST, so
it never reaches a real project. The project id is GCLOUD_PROJECT, or else the default in
.firebaserc, which is the one the emulators run as.

#22 builds the full seed and reset on top of this: add a loader per collection and call it from
main().
"""

import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SEAT_FACTS = ROOT / "data" / "demo" / "invented_seat_facts.json"


def project_id() -> str:
    if project := os.environ.get("GCLOUD_PROJECT"):
        return project
    return json.loads((ROOT / ".firebaserc").read_text())["projects"]["default"]


def seat_facts(path: Path) -> dict[str, dict]:
    """The seats in a demo file, keyed by seat id; its `_note` stays out of Firestore."""
    return json.loads(path.read_text())["seats"]


def load_seat_facts(db, seats: dict[str, dict]) -> int:
    from firebase_admin import firestore

    batch = db.batch()
    for seat_id, fields in seats.items():
        batch.set(
            db.collection("seat_facts").document(seat_id),
            {**fields, "updatedAt": firestore.SERVER_TIMESTAMP},
        )
    batch.commit()
    return len(seats)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--file", type=Path, default=SEAT_FACTS, help="demo seat facts JSON")
    args = parser.parse_args()

    host = os.environ.get("FIRESTORE_EMULATOR_HOST")
    if not host:
        print("FIRESTORE_EMULATOR_HOST is not set: this script only seeds the emulator.")
        return 1

    import firebase_admin
    from firebase_admin import credentials, firestore
    from google.auth.credentials import AnonymousCredentials

    class EmulatorCredential(credentials.Base):
        """The emulator takes no credentials; without one the SDK looks for real ones."""

        def get_credential(self):
            return AnonymousCredentials()

    app = firebase_admin.initialize_app(EmulatorCredential(), {"projectId": project_id()})
    count = load_seat_facts(firestore.client(app), seat_facts(args.file))
    print(f"Seeded {count} seat_facts documents into the emulator at {host}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
