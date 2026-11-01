"""A whole ¿Alguien se suma? on the Firestore emulator with three members, only Muse Spark 1.3
faked: A shares a plan and it is checked, B and C see it on their cards and B joins, A sees B's
first name and nobody else does, B takes it back, A withdraws, and an expired plan is deleted.

    cd functions
    firebase emulators:exec --only firestore,storage --project demo-ronda-shared-plans \\
        "venv/bin/pytest tests/test_shared_plans_emulators.py"

The phone's side (reading a card) goes through the emulator's client API as each member, under
`firestore.rules`; the callables' bodies run on an Admin client against the same emulator. Every
person is invented.

Skipped without the emulators' hosts, and on any project that isn't a `demo-*` one; CI runs it
under `emulators:exec`, where skipping fails.
"""

from datetime import UTC, datetime

import httpx
import pytest
from google.auth.credentials import AnonymousCredentials
from google.cloud import firestore

import shared_plans as sp
from tests.test_voice_signup_emulators import EMULATED, FIRESTORE, PROJECT, WHY
from tests.test_voice_signup_emulators import member_token as token

pytestmark = pytest.mark.skipif(not EMULATED, reason=WHY)

RONDA = "demo-sp-ronda"
ANA, BRUNO, CARLA, OUTSIDER = "demo-sp-1", "demo-sp-2", "demo-sp-3", "demo-sp-4"
WEDNESDAY = datetime(2026, 11, 4, 13, 0, tzinfo=UTC)  # 10:00 in Montevideo
THURSDAY_EVENING = datetime(2026, 11, 5, 22, 5, tzinfo=UTC)  # 19:05 on Thursday, after the walk
PLAN = {
    "rondaId": RONDA,
    "activity": "Caminar 30 minutos por la rambla",
    "place": "desde la parada 23",
    "kind": "walk",
    "date": "2026-11-05",
    "time": "19:00",
}


class Spark:
    def reason(self, line: str) -> str:
        return ""


class Phone:
    """One member's app: the emulator's client API with their token, so the rules apply."""

    def __init__(self, http: httpx.Client, uid: str) -> None:
        self._http, self.uid = http, uid
        self._token = token(uid)

    def read(self, path: str) -> int:
        """The status of reading the document at `path`."""
        return self._http.get(
            f"http://{FIRESTORE}/v1/projects/{PROJECT}/databases/(default)/documents/{path}",
            headers={"Authorization": f"Bearer {self._token}"},
        ).status_code


@pytest.fixture
def db() -> firestore.Client:
    return firestore.Client(project=PROJECT, credentials=AnonymousCredentials())


@pytest.fixture
def http():
    with httpx.Client() as client:
        cleared = client.delete(
            f"http://{FIRESTORE}/emulator/v1/projects/{PROJECT}/databases/(default)/documents"
        )
        assert cleared.status_code == 200
        yield client


@pytest.fixture
def ronda(db, http) -> None:
    db.document(f"rondas/{RONDA}").set({"pretext": "mate", "status": "active"})
    for uid, name in ((ANA, "Ana"), (BRUNO, "Bruno"), (CARLA, "Carla")):
        db.document(f"rondas/{RONDA}/members/{uid}").set({"state": "active"})
        db.document(f"users/{uid}").set({"firstName": name, "terms": {"version": "2026-10-27"}})


def test_a_plan_is_shared_joined_withdrawn_and_expired(db, http, ronda):
    ana, bruno, carla, outsider = (Phone(http, uid) for uid in (ANA, BRUNO, CARLA, OUTSIDER))
    card = f"rondas/{RONDA}/plan_cards/"

    # A held plan leaves nothing behind.
    with pytest.raises(sp.SharedPlanError) as held:
        sp.share(uid=ANA, data={**PLAN, "time": "08:00"}, db=db, checker=Spark(), now=WEDNESDAY)
    assert held.value.reason == "time"
    assert db.document(f"rondas/{RONDA}/shared_plans/{ANA}").get().exists is False

    # A shares: B and C see it on their own cards; the plan itself is closed to everyone.
    sp.share(uid=ANA, data=PLAN, db=db, checker=Spark(), now=WEDNESDAY)
    for phone in (ana, bruno, carla):
        assert phone.read(card + phone.uid) == 200
    assert bruno.read(card + ANA) == 403
    assert outsider.read(card + OUTSIDER) == 403
    for phone in (ana, bruno, carla):
        assert phone.read(f"rondas/{RONDA}/shared_plans/{ANA}") == 403
    line = db.document(card + BRUNO).get().to_dict()["plans"][0]
    assert (line["firstName"], line["activity"], line["joined"]) == (
        "Ana",
        "Caminar 30 minutos por la rambla",
        False,
    )
    assert db.document(card + ANA).get().to_dict()["mine"]["joined"] == []

    # B joins: A sees B's first name; C's card says nothing of it.
    sp.join(db, BRUNO, {"rondaId": RONDA, "authorUid": ANA}, WEDNESDAY)
    assert db.document(card + ANA).get().to_dict()["mine"]["joined"] == ["Bruno"]
    assert db.document(card + BRUNO).get().to_dict()["plans"][0]["joined"] is True
    assert "Bruno" not in str(db.document(card + CARLA).get().to_dict())

    # B takes it back: A's card holds nobody again.
    sp.leave(db, BRUNO, {"rondaId": RONDA, "authorUid": ANA}, WEDNESDAY)
    assert db.document(card + ANA).get().to_dict()["mine"]["joined"] == []

    # A withdraws: every card goes.
    sp.withdraw(db, ANA, {"rondaId": RONDA}, WEDNESDAY)
    assert not any(db.document(card + uid).get().exists for uid in (ANA, BRUNO, CARLA))

    # Shared again, it is deleted by the hourly job once its time has passed.
    sp.share(uid=ANA, data=PLAN, db=db, checker=Spark(), now=WEDNESDAY)
    sp.join(db, CARLA, {"rondaId": RONDA, "authorUid": ANA}, WEDNESDAY)
    assert sp.run_shared_plans(db, WEDNESDAY)["deleted"] == 0
    assert sp.run_shared_plans(db, THURSDAY_EVENING)["deleted"] == 1
    assert db.document(f"rondas/{RONDA}/shared_plans/{ANA}").get().exists is False
    assert not any(db.document(card + uid).get().exists for uid in (ANA, BRUNO, CARLA))
