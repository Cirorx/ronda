"""A test ronda's whole first week (#28's and #48's done-when): the RSVP push, the answers, the
bench filling the seat an "esta no" freed, attendance, and the ¿seguimos? result with the next
week's push.

It runs twice: on the Firestore stand-in with every suite, and on the Firestore emulator when
FIRESTORE_EMULATOR_HOST is set, with Firestore's own transactions:

    scripts/week_on_emulators.sh

The jobs and callables are called as the dispatcher and the functions call them, with an
injected clock, a stand-in sender and a scripted model (no network, no model). Every person is
invented: five neighbours who sign up for mate on Thursday afternoons in El Pinar Sur and are
grouped by the solver, and Eva, who signs up after the ronda formed and waits on its bench.
"""

import os
import urllib.request
from datetime import UTC, datetime

import pytest

import attendance
import bench
import hosts
import proposals
import rsvp
import seguimos
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import DRY, FakeWeather, ScriptedModel, at, call, turn
from tests.test_rsvp import Sender

EMULATOR = os.environ.get("FIRESTORE_EMULATOR_HOST")
PROJECT = os.environ.get("GCLOUD_PROJECT", "")
if not PROJECT.startswith("demo-"):
    PROJECT = "demo-ronda-bench"
"""`firebase emulators:exec --project demo-ronda-bench` sets it; a `demo-*` project, where the
invented sign-ups count (demo_users.py)."""

SEAT = "el-pinar-sur_mate_thu-afternoon"
ADMIN = "demo-admin"
NEIGHBOURS = {
    "demo-401": ("Mirta", "60-69", "termo"),
    "demo-402": ("Jorge", "70-79", "pan"),
    "demo-403": ("Ana", "30-39", "yerba"),
    "demo-404": ("Facu", "18-29", "tengo-ganas"),
    "demo-405": ("Graciela", "60-69", "sillas"),
}
EVA = "demo-406"


def sign_up(uid: str, name: str, age: str, brings: str, day: int) -> dict[str, dict]:
    return {
        f"users/{uid}": {
            "firstName": name,
            "ageBand": age,
            "barrio": "el-pinar-sur",
            "pretexts": ["mate"],
            "slots": ["thu-afternoon"],
            "brings": [brings],
            "createdAt": datetime(2026, 10, day, 12, tzinfo=UTC),
        },
        f"users/{uid}/private/eligible": {"seatIds": [SEAT]},
        f"users/{uid}/tokens/tok-{uid}": {"platform": "android"},
    }


def _clear_emulator() -> None:
    url = f"http://{EMULATOR}/emulator/v1/projects/{PROJECT}/databases/(default)/documents"
    with urllib.request.urlopen(urllib.request.Request(url, method="DELETE"), timeout=30):
        pass


@pytest.fixture(params=["stand-in", "emulator"])
def db(request, monkeypatch):
    monkeypatch.setenv("GCLOUD_PROJECT", PROJECT)
    if request.param == "stand-in":
        yield FakeFirestore()
        return
    if not EMULATOR:
        pytest.skip("needs FIRESTORE_EMULATOR_HOST: scripts/week_on_emulators.sh")
    from google.auth.credentials import AnonymousCredentials
    from google.cloud import firestore

    _clear_emulator()
    yield firestore.Client(project=PROJECT, credentials=AnonymousCredentials())
    _clear_emulator()


def write(db, documents: dict[str, dict]) -> None:
    for path, fields in documents.items():
        db.document(path).set(fields)


def read(db, path: str) -> dict:
    snapshot = db.document(path).get()
    return (snapshot.to_dict() or {}) if snapshot.exists else {}


def offer_script() -> list:
    """The model's part, scripted: it reads the forecast and the count, gives Eva until
    Wednesday at noon, and leaves the host's summary to code."""
    return [
        turn(
            call("get_forecast", date="2026-11-05", reason="ver si llueve el jueves"),
            call("count_rsvps", reason="ver cuántos van"),
        ),
        turn(call("offer_bench_seat", deadline="2026-11-04T12:00", reason="falta un día")),
        turn(content="Le ofrecí el lugar a la primera de la lista."),
    ]


def test_a_ronda_goes_through_its_first_week(db):
    sender = Sender()
    week = "2026-W45"

    # The ronda: five sign-ups, grouped by the solver and approved on Monday; the admin sets its
    # place, hour and hosts. Eva signs up that afternoon, too late for it.
    for day, (uid, person) in enumerate(NEIGHBOURS.items(), start=20):
        write(db, sign_up(uid, *person, day=day))
    proposal = proposals.propose(db, ADMIN, at(2, 10))
    [ronda_id] = proposals.approve(db, proposal["proposalId"], ADMIN, at(2, 10, 5))["rondaIds"]
    hosts.set_setup(
        db,
        {
            "rondaId": ronda_id,
            "place": {"name": "frente al quiosco", "landmark": "al lado de la parada"},
            "hour": "16:00",
            "anfitrion": "demo-401",
            "cola": "demo-402",
        },
        at(2, 11),
    )
    write(db, sign_up(EVA, "Eva", "40-49", "bizcochos", day=30))

    # Tuesday 19:00: the RSVP push reaches the five.
    pushed = rsvp.run_rsvp_push(db, at(3, 19), send=sender, app_url="https://x.test/app/ronda")
    assert pushed["pushed"] == 1 and pushed["messages"] == 5
    assert {m["data"]["type"] for m in sender.messages} == {"rsvp"}

    # The answers: four "voy", and Ana's "esta no".
    for uid in ("demo-401", "demo-402", "demo-404", "demo-405"):
        rsvp.answer(db, uid, ronda_id, "yes", at(3, 19, 10), week=week)
    rsvp.answer(db, "demo-403", ronda_id, "no", at(3, 19, 20), week=week)

    # The bench: code picks Eva, the model gives her until Wednesday at 12:00, and the offer
    # goes through the gates.
    sender.messages.clear()
    ran = bench.run_bench(
        db,
        at(3, 19, 25),
        send=sender,
        model=ScriptedModel(offer_script()),
        weather=FakeWeather(DRY),
    )
    assert ran["offered"] == 1
    [offer_message] = sender.messages
    assert offer_message["token"] == f"tok-{EVA}"
    assert offer_message["data"]["type"] == "benchOffer"
    assert offer_message["data"]["title"] == "Se liberó un lugar para el jueves 5/11"
    assert offer_message["data"]["body"].endswith(
        "Jueves 16:00 · mate en la rambla · frente al quiosco. Estabas en la lista de espera. "
        "¿Lo tomás? Tenés hasta mañana a las 12:00."
    )
    offer_id = offer_message["data"]["offerId"]

    # Eva taps [Lo tomo]: she shows as going, never as a member.
    taken = bench.answer(db, EVA, offer_id, True, at(3, 20))
    assert taken["status"] == "taken"
    view = read(db, f"rondas/{ronda_id}/views/week")
    assert [(p["firstName"], p.get("guest", False)) for p in view["going"]] == [
        ("Eva", True),
        ("Facu", False),
        ("Graciela", False),
        ("Jorge", False),
        ("Mirta", False),
    ]
    assert view["noCount"] == 1 and view["unansweredCount"] == 0
    assert not db.document(f"rondas/{ronda_id}/members/{EVA}").get().exists

    # The next run records her answer and, the bench settled, tells Mirta, who opens.
    sender.messages.clear()
    bench.run_bench(db, at(3, 20, 5), send=sender, model=ScriptedModel([]))
    [summary] = sender.messages
    assert summary["token"] == "tok-demo-401"
    assert summary["data"]["body"].endswith(
        "Para el jueves 5/11 se liberó un lugar. Eva viene de la lista de espera."
    )
    trace = [
        (step["kind"], step["by"])
        for step in sorted(
            (
                s.to_dict()
                for s in db.collection(f"agent_runs/{ronda_id}_{week}_bench/steps").stream()
            ),
            key=lambda s: s["n"],
        )
    ]
    assert ("model", "model") in trace and ("message", "code") in trace
    assert ("answer", "person") in trace
    assert {by for _, by in trace} == {"code", "model", "person"}

    # Thursday 17:00: Mirta is asked who came; Eva is on the roll, and Mirta marks everyone.
    sender.messages.clear()
    asked = attendance.run_attendance_ask(db, at(5, 17), send=sender)
    assert asked["asked"] == 1
    roll = read(db, f"rondas/{ronda_id}/rolls/{week}")
    assert [p["firstName"] for p in roll["people"]] == [
        "Ana",
        "Eva",
        "Facu",
        "Graciela",
        "Jorge",
        "Mirta",
    ]
    for person in roll["people"]:
        came = person["uid"] != "demo-403"
        attendance.record(
            db,
            "demo-401",
            False,
            {"rondaId": ronda_id, "week": week, "uid": person["uid"], "came": came},
            at(5, 17, 10),
        )
    assert read(db, f"rondas/{ronda_id}/weeks/{week}")["attendance"][EVA] is True

    # Thursday 20:00: ¿seguimos? goes to the five members, not to Eva; four say yes, one no.
    seguimos.run_seguimos_ask(db, at(5, 20), send=sender)
    private = read(db, f"rondas/{ronda_id}/private/seguimos")
    assert private["asked"] == sorted(NEIGHBOURS)
    for uid in NEIGHBOURS:
        seguimos.answer(
            db, uid, ronda_id, at(5, 20, 30), value="no" if uid == "demo-404" else "yes"
        )

    # The next Tuesday's push closes it: the season starts, Facu leaves, nobody learns who.
    sender.messages.clear()
    rsvp.run_rsvp_push(db, at(10, 19), send=sender)
    ronda = read(db, f"rondas/{ronda_id}")
    assert ronda["status"] == "active"
    assert ronda["season"] == {"start": "2026-11-12", "end": "2026-12-03"}
    assert read(db, f"rondas/{ronda_id}/seguimos/demo-401")["outcome"] == "season"
    assert read(db, f"rondas/{ronda_id}/seguimos/demo-404")["outcome"] == "gracias"
    bodies = {m["token"]: m["data"]["body"] for m in sender.messages}
    assert bodies["tok-demo-401"].startswith(
        "Seguimos los jueves, hasta el jueves 3/12. Nadie sabe qué contestó cada uno."
    )
    assert f"tok-{EVA}" not in bodies
    assert read(db, f"seguimos_counts/{ronda_id}")["yes"] == 4
