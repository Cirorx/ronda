"""reset.py against the running emulators; skipped when their hosts aren't set.

    cd scripts
    FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \\
        uv run pytest

Uses its own project id, so it never wipes what the app's project holds in the same emulators.
"""

import json
import os
import shutil
import subprocess
import urllib.request
from pathlib import Path

import pytest

import demo_data
import reset
import seed

ROOT = Path(__file__).resolve().parents[2]
PROJECT = "demo-ronda-reset"
FIRESTORE = os.environ.get("FIRESTORE_EMULATOR_HOST")
AUTH = os.environ.get("FIREBASE_AUTH_EMULATOR_HOST")

pytestmark = pytest.mark.skipif(
    not (FIRESTORE and AUTH),
    reason="needs FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST",
)


@pytest.fixture(autouse=True)
def project(monkeypatch):
    monkeypatch.setenv("GCLOUD_PROJECT", PROJECT)
    yield PROJECT
    reset.clear(PROJECT)


def dump() -> dict[str, dict]:
    """Every document of the project by path, fields only (not create or update times)."""
    client = seed.firestore_client(PROJECT)
    state: dict[str, dict] = {}

    def walk(collection) -> None:
        for reference in collection.list_documents():
            if (snapshot := reference.get()).exists:
                state[reference.path] = snapshot.to_dict()
            for subcollection in reference.collections():
                walk(subcollection)

    for collection in client.collections():
        walk(collection)
    return state


def auth_accounts() -> int:
    return int(_auth("accounts:query", {})["recordsCount"])


def _auth(method: str, body: dict) -> dict:
    request = urllib.request.Request(
        f"http://{AUTH}/identitytoolkit.googleapis.com/v1/projects/{PROJECT}/{method}",
        data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer owner", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def sign_up_someone_on_the_phone() -> None:
    """What a recording leaves behind: an account and a profile that aren't demo data."""
    _auth("accounts", {"localId": "phone-user", "email": "vecina@example.com"})
    seed.write(
        seed.firestore_client(PROJECT),
        {
            "users/phone-user": {"firstName": "Vecina", "ageBand": "60-69"},
            "users/phone-user/private/eligible": {"seatIds": [], "updatedAt": demo_data.DEMO_TIME},
        },
    )


@pytest.mark.skipif(not shutil.which("uv"), reason="needs uv on PATH")
def test_resetting_twice_with_the_documented_command_leaves_identical_state():
    command = ["uv", "run", "--python", "3.13", "scripts/reset.py"]
    sign_up_someone_on_the_phone()
    assert auth_accounts() == 1

    states = []
    for _ in range(2):
        subprocess.run(command, cwd=ROOT, check=True, capture_output=True)
        assert auth_accounts() == 0
        states.append(dump())

    first, second = states
    assert first == second
    assert first == demo_data.documents(30)
    assert len(first) == 205  # 144 seat facts, 30 profiles, 30 eligible documents, 1 avoid pair


def test_reset_after_the_two_hundred_set_leaves_only_the_thirty():
    assert reset.main(["200"]) == 0
    assert len(dump()) == len(demo_data.documents(200))

    assert reset.main([]) == 0

    assert dump() == demo_data.documents(30)


def test_seeding_again_changes_nothing():
    assert reset.main([]) == 0
    before = dump()

    assert seed.main(["30"]) == 0

    assert dump() == before


def a_real_member() -> demo_data.Documents:
    """What the pilot leaves behind on the real project: an account and documents not demo data."""
    _auth("accounts", {"localId": "member-1", "email": "vecina@example.com"})
    member = {
        "users/member-1": {"firstName": "Vecina", "ageBand": "60-69"},
        "users/member-1/private/eligible": {"seatIds": [], "updatedAt": demo_data.DEMO_TIME},
        "avoid/member-1_member-2": {"uidA": "member-1", "uidB": "member-2"},
        "seat_facts/real-seat": {"barrio": "solymar", "updatedAt": demo_data.DEMO_TIME},
    }
    seed.write(seed.firestore_client(PROJECT), member)
    return member


@pytest.mark.skipif(not shutil.which("uv"), reason="needs uv on PATH")
def test_resetting_a_project_twice_replaces_only_the_demo_data():
    command = ["uv", "run", "--python", "3.13", "scripts/reset.py", "--project", PROJECT]
    member = a_real_member()

    states = []
    for _ in range(2):
        subprocess.run(command, cwd=ROOT, check=True, capture_output=True)
        assert auth_accounts() == 1
        states.append(dump())

    first, second = states
    assert first == second
    assert first == demo_data.documents(30) | member


def test_a_project_reset_after_the_two_hundred_set_leaves_only_the_thirty():
    member = a_real_member()
    assert reset.main(["200", "--project", PROJECT]) == 0

    assert reset.main(["--project", PROJECT]) == 0

    assert dump() == demo_data.documents(30) | member


def test_a_project_reset_deletes_what_hangs_under_a_demo_profile():
    assert reset.main(["--project", PROJECT]) == 0
    stray = {"users/demo-001/private/voice": {"note": "invented"}, "users/demo-9999": {}}
    seed.write(seed.firestore_client(PROJECT), stray)

    assert reset.main(["--project", PROJECT]) == 0

    assert dump() == demo_data.documents(30)


def test_a_project_reset_stops_before_deleting_when_a_seat_fact_was_changed(capsys):
    assert reset.main(["--project", PROJECT]) == 0
    seat = next(path for path in demo_data.documents(30) if path.startswith("seat_facts/"))
    client = seed.firestore_client(PROJECT)
    client.document(seat).update({"hasStairs": True})
    before = dump()

    assert reset.main(["--project", PROJECT]) == 1

    assert dump() == before
    assert seat in capsys.readouterr().out


def a_ronda(ronda_id: str, uids: list[str]) -> demo_data.Documents:
    """What `approve_proposal` and the weekly RSVP leave for a group of `uids` (ARCHITECTURE.md §
    Data model): the ronda, its members, each member's index, a week, the view and the answers."""
    at = demo_data.DEMO_TIME
    ronda = {
        f"rondas/{ronda_id}": {
            "seatId": "solymar-norte_mate_thu-afternoon",
            "pretext": "mate",
            "barrio": "solymar-norte",
            "slot": {"day": "thu", "time": "afternoon"},
            "size": len(uids),
            "status": "forming",
            "openSeatFromWeek": 4,
            "createdAt": at,
        },
        f"rondas/{ronda_id}/weeks/2026-W45": {"date": "2026-11-05", "rsvp": {uids[0]: "yes"}},
        f"rondas/{ronda_id}/views/week": {"week": "2026-W45", "noCount": 0, "updatedAt": at},
    }
    for uid in uids:
        ronda[f"rondas/{ronda_id}/members/{uid}"] = {
            "brings": [],
            "state": "active",
            "joinedAt": at,
        }
        ronda[f"rondas/{ronda_id}/answers/{uid}"] = {"week": "2026-W45", "answer": "yes", "at": at}
        ronda[f"users/{uid}/rondas/{ronda_id}"] = {"joinedAt": at}
    return ronda


def a_proposal(uids: list[str], unseated: list[str], ronda_ids: list[str]) -> dict:
    """An approved `proposals/{id}` with one group of `uids`."""
    members = [
        {"uid": uid, "firstName": "Ana", "ageBand": "60-69", "distanceBlocks": 3} for uid in uids
    ]
    return {
        "status": "approved",
        "groups": [{"id": "solymar-norte_mate_thu-afternoon", "members": members}],
        "unseated": unseated,
        "rondaIds": ronda_ids,
        "createdAt": demo_data.DEMO_TIME,
    }


def test_a_project_reset_deletes_the_proposals_and_rondas_built_from_demo_uids_alone(capsys):
    assert reset.main(["--project", PROJECT]) == 0
    member = a_real_member()
    built_from_demo = a_ronda("demo-built", ["demo-001", "demo-002"]) | {
        "proposals/demo-built": a_proposal(["demo-001", "demo-002"], ["demo-003"], ["demo-built"]),
    }
    real = a_ronda("real", ["member-1"]) | {
        "proposals/real": a_proposal(["member-1"], [], ["real"]),
    }
    mixed = a_ronda("mixed", ["demo-004", "member-1"]) | {
        "proposals/mixed": a_proposal(["demo-004"], ["member-1"], ["mixed"]),
        "rondas/no-members": {"pretext": "truco", "status": "forming"},
    }
    seed.write(seed.firestore_client(PROJECT), built_from_demo | real | mixed)
    capsys.readouterr()

    assert reset.main(["--project", PROJECT]) == 0

    # The demo users go with their whole subtree, so a mixed ronda's demo index goes too.
    kept = {path: fields for path, fields in mixed.items() if not path.startswith("users/demo-")}
    assert dump() == demo_data.documents(30) | member | real | kept
    out = capsys.readouterr().out
    for path in ("proposals/mixed", "proposals/real", "rondas/mixed", "rondas/no-members"):
        assert path in out
    assert "demo-built" not in out
