"""A ronda that forms itself on the Firestore emulator: two members whose phones marked the same
seat, the admin's hold at 0, one run of the `auto_form` job, and each member's phone finding a
complete Mi ronda card (place, hour and who opens) under `firestore.rules`. Only the model is
scripted; every person and place is invented.

    cd functions
    firebase emulators:exec --only firestore,storage --project demo-ronda-auto-form \\
        "venv/bin/pytest tests/test_auto_form_emulators.py"

Skipped without the emulators' hosts, and on any project that isn't a `demo-*` one; CI runs it
under `emulators:exec`, where skipping fails.
"""

import httpx
import pytest
from google.auth.credentials import AnonymousCredentials
from google.cloud import firestore

import auto_form
import jobs
from tests.auto_form_fakes import MON_10, PEOPLE, sign_ups
from tests.organiser_fakes import ScriptedModel, call, turn
from tests.test_rsvp import Sender
from tests.test_voice_signup_emulators import EMULATED, FIRESTORE, PROJECT, WHY
from tests.test_voice_signup_emulators import member_token as token

pytestmark = pytest.mark.skipif(not EMULATED, reason=WHY)

DOCUMENTS = f"http://{FIRESTORE}/v1/projects/{PROJECT}/databases/(default)/documents"


def value(field: dict):
    """A Firestore REST `Value` as Python, for the types a ronda holds."""
    if "mapValue" in field:
        return {k: value(v) for k, v in field["mapValue"].get("fields", {}).items()}
    if "arrayValue" in field:
        return [value(v) for v in field["arrayValue"].get("values", [])]
    return next(iter(field.values()))


class Phone:
    """One member's app reading through the emulator's REST API with their token."""

    def __init__(self, http: httpx.Client, uid: str) -> None:
        self._http = http
        self._headers = {"Authorization": f"Bearer {token(uid)}"}
        self.uid = uid

    def list(self, path: str) -> list[str]:
        answer = self._http.get(f"{DOCUMENTS}/{path}", headers=self._headers)
        answer.raise_for_status()
        return [d["name"].rsplit("/", 1)[1] for d in answer.json().get("documents", [])]

    def get(self, path: str) -> tuple[int, dict]:
        answer = self._http.get(f"{DOCUMENTS}/{path}", headers=self._headers)
        fields = answer.json().get("fields", {}) if answer.status_code == 200 else {}
        return answer.status_code, {k: value(v) for k, v in fields.items()}


@pytest.fixture
def db() -> firestore.Client:
    client = firestore.Client(project=PROJECT, credentials=AnonymousCredentials())
    for path, fields in sign_ups().items():
        client.document(path).set(fields)
    return client


def test_two_neighbours_get_a_complete_card_without_the_admin_tapping_anything(db):
    auto_form.set_config(db, {"enabled": True, "holdMinutes": 0}, "demo-admin", MON_10)
    model = ScriptedModel(
        [
            turn(
                call(
                    "propose_setup",
                    place_id="plaza-inventada",
                    hour="16:30",
                    host="m2",
                    reason="La plaza queda cerca de los dos; abre m2.",
                )
            ),
            turn(content="Listo."),
        ]
    )
    sender = Sender()

    counts = auto_form.run_auto_form(db, MON_10, send=sender, model=model)

    assert (counts["formed"], counts["agent"], counts["approved"]) == (1, 1, 1)
    # 10:00 in Montevideo: inside the hours, so each member is told at once.
    assert sorted(m["token"] for m in sender.messages) == ["tok-demo-af-1", "tok-demo-af-2"]
    with httpx.Client() as http:
        for uid in PEOPLE:
            phone = Phone(http, uid)
            [ronda_id] = phone.list(f"users/{uid}/rondas")
            status, ronda = phone.get(f"rondas/{ronda_id}")
            assert status == 200
            assert ronda["place"] == {"name": "la Plaza Inventada"}
            assert ronda["slot"] == {"day": "thu", "time": "afternoon", "hour": "16:30"}
            assert (ronda["hosts"]["anfitrionName"], ronda["hosts"]["colaName"]) == (
                "Beto",
                "Ana",
            )
            # The proposal itself stays the admin's.
            [proposal_id] = [s.id for s in db.collection("proposals").stream()]
            assert phone.get(f"proposals/{proposal_id}")[0] == 403

    # The next hour finds nothing to form and nothing to tell.
    assert jobs.run("auto_form", db, MON_10, jobs.Context(send=sender))["formed"] == 0
    assert len(sender.messages) == 2
