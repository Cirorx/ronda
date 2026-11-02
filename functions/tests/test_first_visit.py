"""Así va a ser and who waits for a newcomer (first_visit.py), over the Firestore stand-in. The
ronda is the rain check's: Thursday 2026-11-05 at 16:00 in Montevideo, frente al quiosco.
Mirta (demo-101) opens and Jorge (demo-102) closes; Ana (demo-103) said "esta no" and Facu
(demo-104) hasn't answered. Nico (demo-105) joined on Monday. Every person is invented."""

from datetime import timedelta

import pytest

import first_visit
import ronda_members
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import JOINED, RONDA, WEEK, at, documents

HOSTS = {"anfitrion": "demo-101", "cola": "demo-102"}
NICO = "demo-105"
NICO_JOINED = at(2, 12)
WELCOME = f"rondas/{RONDA}/welcomes/{NICO}"
TUE_10 = at(3, 10)


def ronda(**fields) -> FakeFirestore:
    db = FakeFirestore(documents(hosts=HOSTS, **fields))
    db.documents[f"rondas/{RONDA}/members/{NICO}"] = {
        "brings": ["bizcochos"],
        "state": "active",
        "joinedAt": NICO_JOINED,
    }
    db.documents[f"users/{NICO}"] = {"firstName": "Nico", "ageBand": "30-39"}
    return db


def welcomed(**fields) -> FakeFirestore:
    db = ronda(**fields)
    first_visit.run_first_visit(db, TUE_10)
    return db


def pick(db, uid="demo-101", now=TUE_10, **data):
    return first_visit.set_waiter(
        db, uid, {"rondaId": RONDA, "newcomerUid": NICO, "waiterUid": "demo-102", **data}, now
    )


def choices(*uids) -> list[dict]:
    names = {"demo-101": "Mirta", "demo-102": "Jorge", "demo-103": "Ana", "demo-104": "Facu"}
    return [{"uid": uid, "firstName": names[uid]} for uid in uids]


class TestNewcomers:
    def test_a_member_who_joined_within_the_week_is_new_earliest_first(self):
        members = {
            "old": {"joinedAt": JOINED},
            "b": {"joinedAt": NICO_JOINED},
            "a": {"joinedAt": NICO_JOINED - timedelta(hours=1)},
        }

        assert first_visit.newcomers(members, TUE_10) == ["a", "b"]

    def test_nobody_is_new_while_everyone_is(self):
        members = {"a": {"joinedAt": NICO_JOINED}, "b": {"joinedAt": NICO_JOINED}}

        assert first_visit.newcomers(members, TUE_10) == []

    def test_paused_old_and_dateless_members_are_not_new(self):
        members = {
            "old": {"joinedAt": JOINED},
            "paused": {"state": "paused", "joinedAt": NICO_JOINED},
            "nodate": {"joinedAt": "2026-11-02"},
            "left": {"state": "left", "joinedAt": NICO_JOINED},
        }

        assert first_visit.newcomers(members, TUE_10) == []


class TestTheJob:
    def test_writes_the_welcome_for_the_upcoming_meeting(self):
        db = ronda()

        counts = first_visit.run_first_visit(db, TUE_10)

        assert counts == {"rondas": 1, "welcomes": 1}
        assert db.documents[WELCOME] == {
            "week": WEEK,
            "date": "2026-11-05",
            "hour": "16:00",
            "newcomerName": "Nico",
            "choices": choices("demo-104", "demo-102", "demo-101"),
            "status": "open",
            "declined": [],
            "createdAt": TUE_10,
            "updatedAt": TUE_10,
        }

    def test_is_safe_to_run_again(self):
        db = welcomed()
        db.documents[WELCOME]["status"] = "set"

        assert first_visit.run_first_visit(db, at(3, 11)) == {"rondas": 1, "welcomes": 0}
        assert db.documents[WELCOME]["status"] == "set"

    def test_keeps_who_could_wait_current_as_answers_come_in(self):
        db = welcomed()
        db.documents[WELCOME]["status"] = "set"
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"]["demo-104"] = "no"
        db.documents[f"rondas/{RONDA}/welcomes/other"] = {"week": "2026-W44", "choices": []}

        first_visit.run_first_visit(db, at(3, 11))

        assert db.documents[WELCOME]["choices"] == choices("demo-102", "demo-101")
        assert db.documents[WELCOME]["updatedAt"] == at(3, 11)
        assert db.documents[WELCOME]["status"] == "set"
        assert db.documents[f"rondas/{RONDA}/welcomes/other"]["choices"] == []

    def test_skips_a_newcomer_who_isnt_coming(self):
        db = ronda()
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"][NICO] = "no"

        assert first_visit.run_first_visit(db, TUE_10)["welcomes"] == 0

    def test_skips_a_paused_newcomer(self):
        db = ronda()
        db.documents[f"rondas/{RONDA}/members/{NICO}"]["state"] = "paused"
        db.documents[f"rondas/{RONDA}/members/{NICO}"]["pausedUntil"] = "2026-11-12"

        assert first_visit.run_first_visit(db, TUE_10)["welcomes"] == 0

    def test_writes_nothing_once_the_meeting_started(self):
        db = ronda()

        assert first_visit.run_first_visit(db, at(5, 16))["welcomes"] == 0

    def test_skips_rondas_that_no_longer_meet(self):
        db = ronda(status="ended")

        assert first_visit.run_first_visit(db, TUE_10) == {"rondas": 0, "welcomes": 0}

    def test_follows_a_rain_postponement(self):
        db = ronda()
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["dateOverride"] = "2026-11-06"

        first_visit.run_first_visit(db, TUE_10)

        assert db.documents[WELCOME]["date"] == "2026-11-06"

    def test_sumar_a_esta_ronda_writes_it_at_once(self):
        db = ronda()
        del db.documents[f"rondas/{RONDA}/members/{NICO}"]
        db.documents[f"users/{NICO}"] = {
            "firstName": "Nico",
            "barrio": "el-pinar-sur",
            "brings": ["bizcochos"],
        }

        ronda_members.add(db, RONDA, NICO, TUE_10)

        assert db.documents[WELCOME]["newcomerName"] == "Nico"


class TestTheHostsPick:
    def test_the_anfitrion_picks_a_member_and_a_sign(self):
        db = welcomed()

        result = pick(db, sign="  tiene el   termo verde ")

        assert result == {"status": "set", "waiterUid": "demo-102"}
        welcome = db.documents[WELCOME]
        assert {k: welcome[k] for k in ("status", "waiterUid", "waiterName", "sign")} == {
            "status": "set",
            "waiterUid": "demo-102",
            "waiterName": "Jorge",
            "sign": "tiene el termo verde",
        }
        assert (welcome["setBy"], welcome["setByName"]) == ("demo-101", "Mirta")
        assert welcome["updatedAt"] == TUE_10

    def test_the_cola_waits_themself_without_a_sign(self):
        db = welcomed()
        db.documents[WELCOME]["sign"] = "old"

        pick(db, uid="demo-102", waiterUid="demo-102", sign="")

        welcome = db.documents[WELCOME]
        assert (welcome["waiterName"], welcome["setByName"]) == ("Jorge", "Jorge")
        assert "sign" not in welcome

    def test_a_new_pick_replaces_the_last_and_clears_its_no(self):
        db = welcomed()
        pick(db)
        first_visit.decline(db, "demo-102", {"rondaId": RONDA, "newcomerUid": NICO}, TUE_10)

        pick(db, waiterUid="demo-102")

        welcome = db.documents[WELCOME]
        assert (welcome["declined"], "declinedName" in welcome) == ([], False)

    def test_only_a_host_picks(self):
        db = welcomed()

        with pytest.raises(first_visit.WelcomeError) as excinfo:
            pick(db, uid="demo-104")
        assert excinfo.value.code == "permission-denied"

    @pytest.mark.parametrize("waiter", ["demo-103", NICO, "stranger", None])
    def test_the_waiter_is_a_member_in_for_the_meeting_but_the_newcomer(self, waiter):
        db = welcomed()

        with pytest.raises(first_visit.WelcomeError) as excinfo:
            pick(db, waiterUid=waiter)
        assert excinfo.value.code == "invalid-argument"

    @pytest.mark.parametrize(
        ("sign", "gate"),
        [
            ("tiene el termo verde 🧉", "emoji"),
            ("tienes que buscar el termo", "voseo"),
            ("trae 200 pesos", "money"),
            ("vive en Av. Central 1234", "public_place"),
        ],
    )
    def test_a_sign_the_gates_hold_says_which_gate(self, sign, gate):
        db = welcomed()

        with pytest.raises(first_visit.WelcomeError) as excinfo:
            pick(db, sign=sign)
        assert (excinfo.value.code, excinfo.value.reason) == ("failed-precondition", gate)
        assert db.documents[WELCOME]["status"] == "open"

    @pytest.mark.parametrize("sign", [42, "x" * 61])
    def test_a_sign_is_a_short_string(self, sign):
        db = welcomed()

        with pytest.raises(first_visit.WelcomeError) as excinfo:
            pick(db, sign=sign)
        assert (excinfo.value.code, excinfo.value.reason) == ("invalid-argument", None)

    def test_a_missing_sign_is_none(self):
        db = welcomed()

        pick(db, sign=None)

        assert "sign" not in db.documents[WELCOME]

    def test_the_pick_closes_when_the_meeting_starts(self):
        db = welcomed()

        with pytest.raises(first_visit.WelcomeError) as excinfo:
            pick(db, now=at(5, 16))
        assert excinfo.value.code == "failed-precondition"

    def test_a_welcome_for_another_week_is_closed(self):
        db = welcomed()
        db.documents[WELCOME]["week"] = "2026-W44"

        with pytest.raises(first_visit.WelcomeError) as excinfo:
            pick(db)
        assert excinfo.value.code == "failed-precondition"

    @pytest.mark.parametrize(
        ("data", "code"),
        [
            ("nope", "invalid-argument"),
            ({"newcomerUid": NICO}, "invalid-argument"),
            ({"rondaId": "a/b", "newcomerUid": NICO}, "invalid-argument"),
            ({"rondaId": RONDA}, "invalid-argument"),
            ({"rondaId": "nope", "newcomerUid": NICO}, "not-found"),
            ({"rondaId": RONDA, "newcomerUid": "demo-104"}, "not-found"),
        ],
    )
    def test_refuses_what_isnt_a_welcome(self, data, code):
        db = welcomed()

        with pytest.raises(first_visit.WelcomeError) as excinfo:
            first_visit.set_waiter(db, "demo-101", data, TUE_10)
        assert excinfo.value.code == code


class TestNoPuedo:
    def test_the_picked_waiter_hands_the_choice_back(self):
        db = welcomed()
        pick(db, sign="tiene el termo verde")

        result = first_visit.decline(
            db, "demo-102", {"rondaId": RONDA, "newcomerUid": NICO}, at(3, 12)
        )

        assert result == {"status": "open"}
        welcome = db.documents[WELCOME]
        assert welcome["status"] == "open"
        for field in ("waiterUid", "waiterName", "sign", "setBy", "setByName"):
            assert field not in welcome
        assert (welcome["declined"], welcome["declinedName"]) == (["demo-102"], "Jorge")
        assert welcome["updatedAt"] == at(3, 12)

    @pytest.mark.parametrize("uid", ["demo-104", "demo-101"])
    def test_only_the_picked_waiter_says_it(self, uid):
        db = welcomed()
        pick(db)

        with pytest.raises(first_visit.WelcomeError) as excinfo:
            first_visit.decline(db, uid, {"rondaId": RONDA, "newcomerUid": NICO}, TUE_10)
        assert excinfo.value.code == "permission-denied"

    def test_there_is_nothing_to_decline_before_a_pick(self):
        db = welcomed()

        with pytest.raises(first_visit.WelcomeError) as excinfo:
            first_visit.decline(db, "demo-102", {"rondaId": RONDA, "newcomerUid": NICO}, TUE_10)
        assert excinfo.value.code == "permission-denied"

    def test_refuses_data_that_isnt_an_object(self):
        with pytest.raises(first_visit.WelcomeError) as excinfo:
            first_visit.decline(welcomed(), "demo-102", None, TUE_10)
        assert excinfo.value.code == "invalid-argument"
