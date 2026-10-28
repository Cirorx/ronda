# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = [
#     "google-cloud-firestore>=2.21,<3",
#     "ortools==9.15.6755",
#     "protobuf==6.33.6",
# ]
# ///
"""Write Ronda's invented demo sign-ups and seat facts into the Firestore emulator.

From the repo root:

    FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 uv run --python 3.13 scripts/seed.py 30

`30` is the golden path's set (the solver's fixture people), `200` the scale set; the documents
are built by demo_data.py. A document already at the same path is replaced and nothing else is
touched, so for a clean state run reset.py instead.

Emulator only: it refuses to run without FIRESTORE_EMULATOR_HOST. The project is GCLOUD_PROJECT,
or else the default in .firebaserc, which is the one the emulators run as.
"""

import argparse
import json
import os
import sys
from pathlib import Path

from google.auth.credentials import AnonymousCredentials
from google.cloud import firestore

import demo_data

ROOT = Path(__file__).resolve().parents[1]
FIRESTORE_HOST = "FIRESTORE_EMULATOR_HOST"
BATCH_LIMIT = 500
"""Firestore's most writes in one batch."""


def project_id() -> str:
    if project := os.environ.get("GCLOUD_PROJECT"):
        return project
    return json.loads((ROOT / ".firebaserc").read_text())["projects"]["default"]


def missing_hosts(*variables: str) -> list[str]:
    """The emulator host variables that aren't set."""
    return [variable for variable in variables if not os.environ.get(variable)]


def firestore_client(project: str) -> firestore.Client:
    """A client on the emulator: with FIRESTORE_EMULATOR_HOST set it takes no credentials."""
    return firestore.Client(project=project, credentials=AnonymousCredentials())


def write(client: firestore.Client, documents: demo_data.Documents) -> int:
    """Sets every document at its path, replacing what was there."""
    paths = list(documents)
    for start in range(0, len(paths), BATCH_LIMIT):
        batch = client.batch()
        for path in paths[start : start + BATCH_LIMIT]:
            batch.set(client.document(path), documents[path])
        batch.commit()
    return len(paths)


def seed(people: int) -> int:
    """Writes the demo state for `people` sign-ups into the emulator's project."""
    return write(firestore_client(project_id()), demo_data.documents(people))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("people", type=int, choices=demo_data.SET_SIZES, help="sign-ups to seed")
    args = parser.parse_args(argv)

    if missing := missing_hosts(FIRESTORE_HOST):
        print(f"{', '.join(missing)} is not set: this script only seeds the emulator.")
        return 1

    count = seed(args.people)
    print(
        f"Seeded {count} demo documents ({args.people} sign-ups) into {project_id()} "
        f"at {os.environ[FIRESTORE_HOST]}."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
