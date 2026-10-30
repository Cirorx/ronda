"""The después (despues.py), over the Firestore stand-in. The ronda is the rain check's: Thursday
2026-11-05 at 16:00 in Montevideo, four invented members; Mirta (demo-101) opens and Jorge
(demo-102) closes. Every place and address is invented."""

import pytest

import despues
import rsvp
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import HOST, RONDA, WEEK, at, documents
from tests.test_rsvp import Sender

APP = "https://example.test/app/ronda"
MON = at(2, 12)
HOSTS = {"anfitrion": HOST, "cola": "demo-102"}
DOC = f"rondas/{RONDA}/despues/{WEEK}"
HOME = {"kind": "home", "what": "bizcochos", "address": "Av. Central 1234"}


def ronda(**fields) -> FakeFirestore:
    """The ronda, with Leo (demo-900), a guest from the bench this week: never a member, so
    never a host, a home for the después or a reader of it."""
    db = FakeFirestore(documents(hosts=HOSTS, **fields))
    db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["guests"] = {
        "demo-900": {"firstName": "Leo", "brings": [], "offerId": "o1"}
    }
    db.documents["users/demo-900"] = {"firstName": "Leo"}
    return db


def put(db, uid=HOST, sender=None, now=MON, **data):
    return despues.set_despues(
        db, uid, {"rondaId": RONDA, **data}, now, send=sender or Sender(), app_url=APP
    )


class TestSetting:
    def test_a_public_place_is_set_at_once(self):
        db = ronda()

        result = put(db, kind="place", what="  bizcochos ", where="el Café del Puerto")

        assert result == {"week": WEEK, "status": "set"}
        assert db.documents[DOC] == {
            "week": WEEK,
            "date": "2026-11-05",
            "kind": "place",
            "what": "bizcochos",
            "where": "el Café del Puerto",
            "setBy": HOST,
            "setByName": "Mirta",
            "status": "set",
            "updatedAt": MON,
        }
        assert despues.push_words(db, RONDA, WEEK) == (
            "Después, si querés, bizcochos en el Café del Puerto."
        )

    def test_the_hosts_own_home_is_set_at_once_and_the_push_names_it_without_the_address(self):
        db = ronda()

        assert put(db, **HOME)["status"] == "set"

        assert db.documents[DOC]["homeOf"] == HOST
        assert db.documents[DOC]["homeName"] == "Mirta"
        assert db.documents[DOC]["address"] == "Av. Central 1234"
        assert despues.push_words(db, RONDA, WEEK) == (
            "Después, si querés, bizcochos en lo de Mirta."
        )

    def test_none_this_week_says_nothing_in_the_push(self):
        db = ronda()

        assert put(db, kind="none", week=WEEK)["status"] == "set"

        assert db.documents[DOC]["kind"] == "none"
        assert despues.push_words(db, RONDA, WEEK) == ""

    def test_the_cola_and_who_took_over_opening_set_it_too(self):
        db = ronda(opener={"week": WEEK, "uid": "demo-104", "firstName": "Facu"})

        assert put(db, "demo-102", kind="none")["status"] == "set"
        assert put(db, "demo-104", kind="none")["status"] == "set"

    def test_someone_elses_home_waits_for_their_yes(self):
        db = ronda()
        sender = Sender()

        assert put(db, sender=sender, homeOf="demo-103", **HOME)["status"] == "asking"

        assert db.documents[DOC]["homeName"] == "Ana"
        assert despues.push_words(db, RONDA, WEEK) == ""
        assert sender.tokens == ["tok-demo-103"]
        text = sender.messages[0]["data"]["body"]
        assert text.endswith(
            "Mirta pregunta si el después de esta semana puede ser donde vivís. "
            "Lo ves en Ronda y decís si querés."
        )
        assert "Central" not in text and "en lo de" not in text
        assert sender.messages[0]["data"]["type"] == "despues"
        run = db.documents[f"agent_runs/{RONDA}_{WEEK}_despues"]
        assert (run["job"], run["model"], run["status"]) == ("despues", "", "done")
        assert not [path for path in db.documents if path.startswith(f"acta/{RONDA}/")]

    def test_the_question_without_a_name_still_reads(self):
        assert despues.ask_text("").startswith("Quien abre pregunta")

    def test_each_call_replaces_the_weeks_despues(self):
        db = ronda()
        put(db, **HOME)

        put(db, kind="none")

        assert "address" not in db.documents[DOC]


class TestRefusals:
    @pytest.mark.parametrize(
        ("uid", "data", "code"),
        [
            ("demo-104", {"kind": "none"}, "permission-denied"),
            ("demo-999", {"kind": "none"}, "permission-denied"),
            ("demo-900", {"kind": "none"}, "permission-denied"),
            (HOST, {"kind": "party"}, "invalid-argument"),
            (HOST, {"kind": "place", "where": "la plaza"}, "invalid-argument"),
            (HOST, {"kind": "place", "what": "  ", "where": "la plaza"}, "invalid-argument"),
            (HOST, {"kind": "place", "what": "x" * 61, "where": "la plaza"}, "invalid-argument"),
            (
                HOST,
                {"kind": "place", "what": "bizcochos, cada uno pone 100 pesos", "where": "x"},
                "failed-precondition",
            ),
            (
                HOST,
                {"kind": "place", "what": "bizcochos", "where": "Av. Central 1234"},
                "failed-precondition",
            ),
            (HOST, {**HOME, "homeOf": "demo-999"}, "invalid-argument"),
            (HOST, {**HOME, "homeOf": "demo-900"}, "invalid-argument"),
            (HOST, {**HOME, "address": "Av. Central 1234 🏠"}, "failed-precondition"),
            (HOST, {"kind": "none", "week": "2026-W44"}, "failed-precondition"),
            (HOST, {"kind": "none", "rondaId": "nope"}, "not-found"),
            (HOST, {"kind": "none", "rondaId": "a/b"}, "invalid-argument"),
        ],
    )
    def test_refuses(self, uid, data, code):
        db = ronda()

        with pytest.raises(despues.DespuesError) as excinfo:
            put(db, uid, **data)
        assert excinfo.value.code == code
        assert DOC not in db.documents

    def test_a_body_that_isnt_an_object_has_no_ronda(self):
        with pytest.raises(despues.DespuesError) as excinfo:
            despues.set_despues(ronda(), HOST, None, MON, send=Sender())
        assert excinfo.value.code == "invalid-argument"


class TestTheAnswer:
    def asked(self) -> FakeFirestore:
        db = ronda()
        put(db, homeOf="demo-103", **HOME)
        return db

    def test_a_yes_shows_it_to_the_members(self):
        db = self.asked()

        result = despues.answer(
            db, "demo-103", {"rondaId": RONDA, "week": WEEK, "answer": "yes"}, MON
        )

        assert result == {"status": "set"}
        assert db.documents[DOC]["status"] == "set"
        assert db.documents[DOC]["address"] == "Av. Central 1234"
        assert despues.push_words(db, RONDA, WEEK).endswith("en lo de Ana.")

    def test_a_no_deletes_the_address_at_once(self):
        db = self.asked()

        result = despues.answer(
            db, "demo-103", {"rondaId": RONDA, "week": WEEK, "answer": "no"}, MON
        )

        assert result == {"status": "declined"}
        assert db.documents[DOC]["status"] == "declined"
        assert "address" not in db.documents[DOC]

    @pytest.mark.parametrize(
        ("uid", "data", "code"),
        [
            ("demo-103", {"week": WEEK, "answer": "maybe"}, "invalid-argument"),
            ("demo-103", {"answer": "yes"}, "invalid-argument"),
            (HOST, {"week": WEEK, "answer": "yes"}, "permission-denied"),
            ("demo-103", {"week": "2026-W44", "answer": "yes"}, "permission-denied"),
        ],
    )
    def test_refuses(self, uid, data, code):
        with pytest.raises(despues.DespuesError) as excinfo:
            despues.answer(self.asked(), uid, {"rondaId": RONDA, **data}, MON)
        assert excinfo.value.code == code

    def test_there_is_nothing_to_answer_twice(self):
        db = self.asked()
        data = {"rondaId": RONDA, "week": WEEK, "answer": "yes"}
        despues.answer(db, "demo-103", data, MON)

        with pytest.raises(despues.DespuesError) as excinfo:
            despues.answer(db, "demo-103", data, MON)
        assert excinfo.value.code == "failed-precondition"

    def test_a_body_that_isnt_an_object_has_no_ronda(self):
        with pytest.raises(despues.DespuesError):
            despues.answer(ronda(), HOST, "yes", MON)


class TestTheSweep:
    def test_deletes_the_address_once_the_day_is_over(self):
        db = ronda()
        put(db, **HOME)

        assert despues.run_despues_sweep(db, at(5, 23, 59)) == {"deleted": 0}
        assert despues.run_despues_sweep(db, at(6, 0)) == {"deleted": 1}

        assert "address" not in db.documents[DOC]
        assert db.documents[DOC]["addressDeletedAt"] == at(6, 0)
        assert db.documents[DOC]["homeName"] == "Mirta"
        assert despues.run_despues_sweep(db, at(7, 0)) == {"deleted": 0}

    def test_waits_for_the_day_a_rain_move_postponed_it_to(self):
        db = ronda()
        put(db, **HOME)
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["dateOverride"] = "2026-11-06"

        assert despues.run_despues_sweep(db, at(6, 12)) == {"deleted": 0}
        assert despues.run_despues_sweep(db, at(7, 0)) == {"deleted": 1}

    def test_a_week_with_no_document_counts_on_the_despues_date(self):
        db = ronda()
        put(db, **HOME)
        del db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]

        assert despues.run_despues_sweep(db, at(6, 0)) == {"deleted": 1}


class TestTheRsvpPush:
    def test_the_push_carries_the_despues_and_never_the_address(self):
        db = ronda()
        put(db, **HOME)
        del db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvpSentAt"]
        sender = Sender()

        rsvp.run_rsvp_push(db, at(3, 19), send=sender, app_url=APP)

        (message,) = [m for m in sender.messages if m["token"] == "tok-demo-104"]
        assert message["data"]["body"] == (
            "Ya van Jorge y Mirta. Después, si querés, bizcochos en lo de Mirta. ¿Venís?"
        )
        assert all("Central" not in str(m) for m in sender.messages)

    def test_a_despues_still_asking_stays_out_of_the_push(self):
        assert rsvp.push_body([], [], despues="") == "¿Venís?"
