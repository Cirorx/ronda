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
clear endpoints, then seeds the 30 invented sign-ups, the seat facts and the covered places
(seed.py 30). That is the golden path today: seats published, the demo sign-ups present, and the
person on the phone not signed up yet, so onboarding shows. Every seeded timestamp is one fixed
demo moment, so running it twice leaves identical documents. `reset.py 200` gives the same clean
state with the 200 set.
The project is GCLOUD_PROJECT, or else the default in .firebaserc.

On the real project, with Application Default Credentials and no emulator hosts:

    uv run --python 3.13 scripts/reset.py --project ronda-uy

deletes only the invented demo documents (see `clear_demo`), with the proposals and rondas built
from demo uids alone, and writes the set again. Real members' documents, any proposal or ronda that
names one, and every Auth account stay as they are; the seed never creates Auth accounts.
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
"""Every invented uid starts with it. functions/demo_users.py holds the same test, which keeps
these sign-ups out of the real project's Cerca counts and solver input; the scripts don't
import functions/, so tests/test_demo_uids.py checks that the two agree."""


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


def is_demo_uid(uid: object) -> bool:
    """Whether `uid` is one of the invented sign-ups (functions/demo_users.py: the same test)."""
    return str(uid).startswith(DEMO_UID_PREFIX)


def proposal_uids(proposal: dict) -> list[str]:
    """Every uid a `proposals/{id}` names: its groups' members and the unseated."""
    return [
        member.get("uid")
        for group in proposal.get("groups") or []
        for member in group.get("members") or []
    ] + list(proposal.get("unseated") or [])


def built_from_demo(uids: list) -> bool:
    """Whether a proposal or ronda naming `uids` was built from demo people alone: at least one
    uid, and every one a demo uid. One real member keeps it."""
    return bool(uids) and all(is_demo_uid(uid) for uid in uids)


def clear_demo(client: firestore.Client) -> int:
    """Deletes the invented demo documents of `client`'s project and nothing else.

    Demo documents are `users/demo-*` with everything under them, `avoid` pairs naming a demo
    uid, the seat facts either demo set writes, and what the solver and approval built from demo
    people alone: each `proposals/{id}` whose groups and unseated name only demo uids, and each
    `rondas/{id}` whose members are all demo uids, with everything under it (members, weeks,
    views, answers, private, moves) and the organiser's acta and runs about it, and the
    `places/demo-*` the organiser offers when it rains. A proposal or ronda that names any other
    uid, or a ronda with no members, is kept and listed. A seat fact at a demo path that isn't
    the invented one raises NotDemoData before anything is deleted. Returns the documents
    deleted.
    """
    invented = demo_data.documents(30) | demo_data.documents(200)
    seat_paths = [path for path in invented if path.startswith("seat_facts/")]
    seats = list(client.get_all(map(client.document, seat_paths)))
    if changed := [
        s.reference.path for s in seats if s.exists and s.to_dict() != invented[s.reference.path]
    ]:
        raise NotDemoData(f"not the invented seat facts: {', '.join(sorted(changed))}")

    proposals = [
        (snapshot, built_from_demo(proposal_uids(snapshot.to_dict())))
        for snapshot in client.collection("proposals").stream()
    ]
    rondas = [
        (
            ronda,
            built_from_demo([member.id for member in ronda.collection("members").list_documents()]),
        )
        for ronda in client.collection("rondas").list_documents()
    ]
    if kept := [ref.path for ref, demo in rondas if not demo] + [
        snapshot.reference.path for snapshot, demo in proposals if not demo
    ]:
        print(f"Kept, not built from demo uids alone: {', '.join(sorted(kept))}.")

    deleted = 0
    demo_rondas = {ronda.id for ronda, demo in rondas if demo}
    for ronda, demo in rondas:
        if demo:
            deleted += client.recursive_delete(ronda)
            deleted += client.recursive_delete(client.document(f"acta/{ronda.id}"))
    for run in client.collection("agent_runs").stream():
        if run.to_dict().get("rondaId") in demo_rondas:
            deleted += client.recursive_delete(run.reference)
    for place in client.collection("places").list_documents():
        if place.id.startswith(DEMO_UID_PREFIX):
            place.delete()
            deleted += 1
    for snapshot, demo in proposals:
        if demo:
            deleted += client.recursive_delete(snapshot.reference)
    for user in client.collection("users").list_documents():
        if user.id.startswith(DEMO_UID_PREFIX):
            deleted += client.recursive_delete(user)
    for pair in client.collection("avoid").stream():
        fields = pair.to_dict()
        if any(is_demo_uid(fields.get(key, "")) for key in ("uidA", "uidB")):
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
        f"({args.people} sign-ups, the seat facts and the covered places)."
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
        f"{count} ({people} sign-ups, the seat facts and the covered places). Other documents "
        "and Auth untouched."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
