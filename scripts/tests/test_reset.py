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
