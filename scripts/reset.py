# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = [
#     "google-cloud-firestore>=2.21,<3",
#     "ortools==9.15.6755",
#     "protobuf==6.33.6",
# ]
# ///
"""Restore the golden-path demo state in the Firebase emulators, or the demo part of a project.

From the repo root, in the emulators:

    FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \\
        uv run --python 3.13 scripts/reset.py

deletes every Auth account and every Firestore document of the project with the emulators' own
clear endpoints, then seeds the 30 invented sign-ups and the seat facts (seed.py 30). That is the
golden path today: seats published, the demo sign-ups present, and the person on the phone not
signed up yet, so onboarding shows. Every seeded timestamp is one fixed demo moment, so running it
twice leaves identical documents. `reset.py 200` gives the same clean state with the 200 set.
The project is GCLOUD_PROJECT, or else the default in .firebaserc.

On the real project, with Application Default Credentials and no emulator hosts:

    uv run --python 3.13 scripts/reset.py --project ronda-uy

deletes only the invented demo documents (see `clear_demo`) and writes the set again. Real
members' documents and every Auth account stay as they are; the seed never creates Auth accounts.
It stops before deleting anything when a seat fact at a demo path is not the invented one. With
the emulator hosts set, `--project` does the same in the emulators, which is how it is tested.
"""

import argparse
import os
import sys
import urllib.request

from google.cloud import firestore

import demo_data
import seed

AUTH_HOST = "FIREBASE_AUTH_EMULATOR_HOST"
DEMO_UID_PREFIX = "demo-"


class NotDemoData(Exception):
    """A document at a demo path holds something the seed never wrote."""


def clear(project: str) -> None:
    """Deletes every Auth account and Firestore document of `project` in the emulators."""
    auth = os.environ[AUTH_HOST]
    firestore_host = os.environ[seed.FIRESTORE_HOST]
    _delete(f"http://{auth}/emulator/v1/projects/{project}/accounts")
    _delete(f"http://{firestore_host}/emulator/v1/projects/{project}/databases/(default)/documents")


def _delete(url: str) -> None:
    request = urllib.request.Request(url, method="DELETE")
    with urllib.request.urlopen(request, timeout=30):  # raises on any status but 2xx
        pass


def clear_demo(client: firestore.Client) -> int:
    """Deletes the invented demo documents of `client`'s project and nothing else.

    Demo documents are `users/demo-*` with everything under them, `avoid` pairs naming a demo
    uid, and the seat facts either demo set writes. A seat fact at one of those paths that isn't
    the invented one raises NotDemoData before anything is deleted. Returns the documents deleted.
    """
    invented = demo_data.documents(30) | demo_data.documents(200)
    seat_paths = [path for path in invented if path.startswith("seat_facts/")]
    seats = list(client.get_all(map(client.document, seat_paths)))
    if changed := [
        s.reference.path for s in seats if s.exists and s.to_dict() != invented[s.reference.path]
    ]:
        raise NotDemoData(f"not the invented seat facts: {', '.join(sorted(changed))}")

    deleted = 0
    for user in client.collection("users").list_documents():
        if user.id.startswith(DEMO_UID_PREFIX):
            deleted += client.recursive_delete(user)
    for pair in client.collection("avoid").stream():
        fields = pair.to_dict()
        if any(str(fields.get(key, "")).startswith(DEMO_UID_PREFIX) for key in ("uidA", "uidB")):
            pair.reference.delete()
            deleted += 1
    for snapshot in seats:
        if snapshot.exists:
            snapshot.reference.delete()
            deleted += 1
    return deleted


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
    parser.add_argument(
        "--project",
        help="replace only the demo documents of this project, leaving everything else",
    )
    args = parser.parse_args(argv)

    if args.project:
        return _reset_demo(args.project, args.people)

    if missing := seed.missing_hosts(seed.FIRESTORE_HOST, AUTH_HOST):
        print(
            f"{', '.join(missing)} not set: without --project this script only resets the "
            "emulators."
        )
        return 1

    project = seed.project_id()
    clear(project)
    count = seed.seed(args.people)
    print(
        f"Reset {project}: no Auth accounts, {count} demo documents "
        f"({args.people} sign-ups and the seat facts)."
    )
    return 0


def _reset_demo(project: str, people: int) -> int:
    emulator = os.environ.get(seed.FIRESTORE_HOST)
    client = seed.firestore_client(project) if emulator else firestore.Client(project=project)
    where = f"the emulator at {emulator}" if emulator else "the real project"
    try:
        deleted = clear_demo(client)
    except NotDemoData as error:
        print(f"Nothing deleted in {project} ({where}): {error}.")
        return 1
    count = seed.write(client, demo_data.documents(people))
    print(
        f"Reset the demo data of {project} ({where}): deleted {deleted} demo documents, wrote "
        f"{count} ({people} sign-ups and the seat facts). Other documents and Auth untouched."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
