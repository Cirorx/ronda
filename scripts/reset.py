# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = [
#     "google-cloud-firestore>=2.21,<3",
#     "ortools==9.15.6755",
#     "protobuf==6.33.6",
# ]
# ///
"""Restore the golden-path demo state in the Firebase emulators.

From the repo root:

    FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \\
        uv run --python 3.13 scripts/reset.py

Deletes every Auth account and every Firestore document of the project with the emulators' own
clear endpoints, then seeds the 30 invented sign-ups and the seat facts (seed.py 30). That is the
golden path today: seats published, the demo sign-ups present, and the person on the phone not
signed up yet, so onboarding shows. Every seeded timestamp is one fixed demo moment, so running it
twice leaves identical documents. `reset.py 200` gives the same clean state with the 200 set.

Emulator only: it refuses to run without both emulator hosts. The project is GCLOUD_PROJECT, or
else the default in .firebaserc. Resetting the real project waits until Firestore is enabled there.
"""

import argparse
import os
import sys
import urllib.request

import demo_data
import seed

AUTH_HOST = "FIREBASE_AUTH_EMULATOR_HOST"


def clear(project: str) -> None:
    """Deletes every Auth account and Firestore document of `project` in the emulators."""
    auth = os.environ[AUTH_HOST]
    firestore = os.environ[seed.FIRESTORE_HOST]
    _delete(f"http://{auth}/emulator/v1/projects/{project}/accounts")
    _delete(f"http://{firestore}/emulator/v1/projects/{project}/databases/(default)/documents")


def _delete(url: str) -> None:
    request = urllib.request.Request(url, method="DELETE")
    with urllib.request.urlopen(request, timeout=30):  # raises on any status but 2xx
        pass


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "people",
        type=int,
        nargs="?",
        default=30,
        choices=demo_data.SET_SIZES,
        help="sign-ups to seed (default 30, the golden path)",
    )
    args = parser.parse_args(argv)

    if missing := seed.missing_hosts(seed.FIRESTORE_HOST, AUTH_HOST):
        print(f"{', '.join(missing)} not set: this script only resets the emulators.")
        return 1

    project = seed.project_id()
    clear(project)
    count = seed.seed(args.people)
    print(
        f"Reset {project}: no Auth accounts, {count} demo documents "
        f"({args.people} sign-ups and the seat facts)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
