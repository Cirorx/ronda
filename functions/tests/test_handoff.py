"""¿Abrís vos? (handoff.py), over the Firestore stand-in. The ronda is the rain check's: Thursday
2026-11-05 at 16:00 in Montevideo, its RSVP push out on Tuesday. Mirta (demo-101) opens and
Jorge (demo-102) closes; Ana (demo-103) said "esta no" and Facu (demo-104) hasn't answered.
Every person is invented."""

from datetime import date

import pytest

import handoff
import rsvp
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import HOST, RONDA, THURSDAY, WEEK, at, documents
from tests.test_rsvp import Sender

APP = "https://example.test/app/ronda"
HOSTS = {"anfitrion": HOST, "cola": "demo-102"}
STATE = f"rondas/{RONDA}/handoffs/{WEEK}"
WED_10 = at(4, 10)


def ronda(anfitrion_says: str | None = "no", **fields) -> FakeFirestore:
    db = FakeFirestore(documents(hosts=HOSTS, **fields))
    answers = db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"]
    if anfitrion_says is None:
        del answers[HOST]
    else:
        answers[HOST] = anfitrion_says
    return db


def run(db, now=WED_10, sender=None, force=False):
    return handoff.run_handoff(
        db, now, send=sender if sender is not None else Sender(), app_url=APP, force=force
    )


def reply(db, uid, value, now=WED_10, sender=None):
    return handoff.answer(
        db,
        uid,
        {"rondaId": RONDA, "week": WEEK, "answer": value},
        now,
        send=sender if sender is not None else Sender(),
        app_url=APP,
    )


def ask(db, uid) -> dict:
    return db.documents[f"rondas/{RONDA}/handoff_asks/{uid}"]


def acta(db) -> list[tuple[str, str]]:
    return [
        (entry["summary"], entry["decidedBy"])
        for path, entry in sorted(db.documents.items())
        if path.startswith(f"acta/{RONDA}/entries/")
    ]


class TestWhen:
    def test_the_meeting_moves_with_a_rain_postponement(self):
        db = ronda()
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["dateOverride"] = "2026-11-06"
        ronda_doc = db.documents[f"rondas/{RONDA}"]

        assert handoff.meeting_of(db, RONDA, ronda_doc, date(2026, 11, 4)) == (
            date(2026, 11, 6),
            WEEK,
        )

    def test_a_ronda_with_no_hour_starts_with_its_band(self):
        assert handoff.starts_at(THURSDAY, {"slot": {"time": "evening"}}) == at(5, 19)
        assert handoff.starts_at(THURSDAY, {"slot": {"time": "late"}}) == at(5, 14)

    @pytest.mark.parametrize(
        ("today", "words"),
        [(THURSDAY, "hoy"), (date(2026, 11, 4), "mañana"), (date(2026, 11, 2), "el jueves")],
    )
    def test_the_day_is_spoken(self, today, words):
        assert handoff.spoken_day(THURSDAY, today) == words

    def test_opening_has_a_time_only_with_an_hour(self):
        assert handoff.opening_words("16:00") == (
            "Abrir es llegar diez minutos antes, a las 15:50, y saludar a los que van "
            "llegando. Nada más."
        )
        assert handoff.opening_words(None) == (
            "Abrir es llegar diez minutos antes y saludar a los que van llegando. Nada más."
        )


class TestTheCola:
    def test_an_esta_no_asks_the_cola_first(self):
        db = ronda()
        sender = Sender()

        counts = run(db, sender=sender)

        assert counts == {"rondas": 1, "cola": 1}
        state = db.documents[STATE]
        assert (state["step"], state["asked"], state["reason"]) == ("cola", ["demo-102"], "no")
        assert state["deadline"] == at(4, 12)
        assert ask(db, "demo-102") == {
            "week": WEEK,
            "date": "2026-11-05",
            "hour": "16:00",
            "fromName": "Mirta",
            "reason": "no",
            "status": "open",
            "askedAt": WED_10,
        }
        assert sender.tokens == ["tok-demo-102", "tok-web"]
        body = sender.messages[0]["data"]["body"]
        assert body.startswith("Hola, Jorge. Soy un programa.")
        assert body.endswith(
            "Mirta no puede mañana. ¿Abrís vos? Abrir es llegar diez minutos antes, a las 15:50, "
            "y saludar a los que van llegando. Nada más."
        )
        assert sender.messages[0]["data"]["type"] == "handoff"
        assert acta(db) == [("Le preguntó a Jorge si abre el jueves.", "agent")]
        run_doc = db.documents[f"agent_runs/{RONDA}_{WEEK}_handoff"]
        assert (run_doc["job"], run_doc["model"]) == ("handoff", "")

    def test_waits_for_the_cola_then_asks_the_others(self):
        db = ronda()
        run(db)
        sender = Sender()

        assert run(db, at(4, 11), sender) == {"rondas": 1, "waiting": 1}
        assert run(db, at(4, 12), sender) == {"rondas": 1, "members": 1}

        assert db.documents[STATE]["asked"] == ["demo-102", "demo-104"]
        assert ask(db, "demo-102")["status"] == "closed"
        assert ask(db, "demo-104")["fromName"] == ""
        assert ask(db, "demo-104")["reason"] == ""
        assert sender.tokens == ["tok-demo-104"]
        assert sender.messages[0]["data"]["body"].endswith(
            "Todavía nadie abre mañana. ¿Abrís vos? Abrir es llegar diez minutos antes, a las "
            "15:50, y saludar a los que van llegando. Nada más."
        )
        assert acta(db)[-1] == ("Les preguntó a 1 del grupo si alguien abre el jueves.", "agent")

    def test_an_unanswered_anfitrion_counts_from_noon_the_day_before(self):
        db = ronda(anfitrion_says=None)
        sender = Sender()

        assert run(db, at(4, 11), sender) == {"rondas": 1, "idle": 1}
        assert run(db, at(4, 12), sender) == {"rondas": 1, "cola": 1}

        assert (
            "Mirta no confirmó que viene mañana. ¿Abrís vos?"
            in (sender.messages[0]["data"]["body"])
        )

    def test_an_anfitrion_paused_or_gone_cant_open(self):
        paused = ronda(anfitrion_says=None)
        paused.documents[f"rondas/{RONDA}/members/{HOST}"].update(
            state="paused", pausedUntil="2026-11-19"
        )
        gone = ronda(anfitrion_says=None)
        gone.documents[f"rondas/{RONDA}/members/{HOST}"]["state"] = "left"

        for db in (paused, gone):
            assert run(db, at(2, 12)) == {"rondas": 1, "cola": 1}
            assert db.documents[STATE]["reason"] == "away"

    def test_a_guest_from_the_bench_is_never_asked(self):
        db = ronda()
        week = db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]
        week["guests"] = {"demo-900": {"firstName": "Leo", "brings": [], "offerId": "o1"}}
        week["rsvp"]["demo-102"] = "no"

        run(db)

        assert db.documents[STATE]["asked"] == ["demo-104"]

    def test_a_cola_who_cant_come_is_skipped(self):
        db = ronda()
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"]["demo-102"] = "no"

        assert run(db) == {"rondas": 1, "members": 1}
        assert db.documents[STATE]["asked"] == ["demo-104"]


class TestTheAnswer:
    def test_the_colas_yes_opens_it_and_says_voy_for_them(self):
        db = ronda()
        run(db)
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"].pop("demo-102")

        assert reply(db, "demo-102", "yes") == {"status": "taken"}

        state = db.documents[STATE]
        assert (state["step"], state["takenBy"], state["takenName"]) == (
            "taken",
            "demo-102",
            "Jorge",
        )
        assert db.documents[f"rondas/{RONDA}"]["opener"] == {
            "week": WEEK,
            "uid": "demo-102",
            "firstName": "Jorge",
        }
        assert ask(db, "demo-102")["status"] == "taken"
        assert db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"]["demo-102"] == "yes"
        assert acta(db)[-1] == ("Jorge abre el jueves.", "host")
        assert run(db, at(4, 13)) == {"rondas": 1, "idle": 1}

    def test_a_cola_already_going_keeps_their_answer(self, monkeypatch):
        db = ronda()
        run(db)
        monkeypatch.setattr(rsvp, "answer", lambda *args, **kwargs: pytest.fail("answered"))

        assert reply(db, "demo-102", "yes") == {"status": "taken"}

    def test_a_no_passes_the_question_on_at_once(self):
        db = ronda()
        run(db)
        sender = Sender()

        assert reply(db, "demo-102", "no", sender=sender) == {"status": "declined"}

        assert ask(db, "demo-102")["answer"] == "no"
        assert db.documents[STATE]["step"] == "members"
        assert sender.tokens == ["tok-demo-104"]

    def test_the_first_yes_among_the_others_opens_it(self):
        db = ronda()
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"]["demo-103"] = "yes"
        run(db)
        reply(db, "demo-102", "no")

        reply(db, "demo-104", "yes")

        assert db.documents[STATE]["takenBy"] == "demo-104"
        assert ask(db, "demo-103")["status"] == "closed"
        with pytest.raises(handoff.HandoffError) as excinfo:
            reply(db, "demo-103", "yes")
        assert excinfo.value.code == "failed-precondition"

    def test_a_late_yes_finds_someone_else_opening(self):
        db = ronda()
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"]["demo-103"] = "yes"
        run(db)
        reply(db, "demo-102", "no")
        reply(db, "demo-104", "yes")
        ask(db, "demo-103")["status"] = "open"

        with pytest.raises(handoff.HandoffError) as excinfo:
            reply(db, "demo-103", "yes")

        assert excinfo.value.code == "failed-precondition"
        assert ask(db, "demo-103")["status"] == "closed"

    def test_a_voy_that_cant_be_saved_still_opens_it(self, monkeypatch):
        db = ronda()
        run(db)
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"].pop("demo-102")

        def refuse(*args, **kwargs):
            raise rsvp.RsvpError("failed-precondition", "that meeting has passed")

        monkeypatch.setattr(rsvp, "answer", refuse)

        assert reply(db, "demo-102", "yes") == {"status": "taken"}

    def test_everyone_saying_no_leaves_it_to_the_admin(self):
        db = ronda()
        run(db)
        reply(db, "demo-102", "no")

        reply(db, "demo-104", "no")

        assert db.documents[STATE]["step"] == "nobody"
        assert acta(db)[-1] == ("Nadie confirmó que abre el jueves.", "agent")

    @pytest.mark.parametrize(
        ("uid", "data", "code"),
        [
            ("demo-102", {"answer": "maybe"}, "invalid-argument"),
            ("demo-102", {"week": "", "answer": "yes"}, "invalid-argument"),
            ("demo-104", {"answer": "yes"}, "permission-denied"),
        ],
    )
    def test_refuses(self, uid, data, code):
        db = ronda()
        run(db)

        with pytest.raises(handoff.HandoffError) as excinfo:
            handoff.answer(db, uid, {"rondaId": RONDA, "week": WEEK, **data}, WED_10, send=Sender())
        assert excinfo.value.code == code

    def test_an_answered_question_is_closed(self):
        db = ronda()
        run(db)
        reply(db, "demo-102", "no")

        with pytest.raises(handoff.HandoffError) as excinfo:
            reply(db, "demo-102", "yes")
        assert excinfo.value.code == "failed-precondition"

    def test_a_body_that_isnt_an_object_has_no_ronda(self):
        with pytest.raises(handoff.HandoffError):
            handoff.answer(ronda(), HOST, None, WED_10, send=Sender())


class TestTheEnd:
    def test_the_anfitrions_voy_ends_it(self):
        db = ronda()
        run(db)
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"][HOST] = "yes"

        assert run(db, at(4, 11)) == {"rondas": 1, "back": 1}

        assert db.documents[STATE]["step"] == "back"
        assert ask(db, "demo-102")["status"] == "closed"
        assert run(db, at(4, 12)) == {"rondas": 1, "idle": 1}

    def test_the_meeting_starting_ends_it(self):
        db = ronda()
        run(db)

        assert run(db, at(5, 16)) == {"rondas": 1, "late": 1}

        assert db.documents[STATE]["step"] == "nobody"
        assert ask(db, "demo-102")["status"] == "closed"

    def test_nothing_starts_once_the_meeting_has(self):
        assert run(ronda(), at(5, 16)) == {"rondas": 1, "idle": 1}

    def test_with_nobody_else_in_it_goes_to_the_admin_at_once(self):
        db = ronda()
        week = db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"]
        week.update({"demo-102": "no", "demo-104": "no"})

        assert run(db) == {"rondas": 1, "nobody": 1}
        assert acta(db) == [("Nadie confirmó que abre el jueves.", "agent")]


class TestTheJob:
    def test_waits_for_the_weeks_rsvp_push_unless_forced(self):
        db = ronda()
        del db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvpSentAt"]

        assert run(db) == {"rondas": 1, "idle": 1}
        assert run(db, force=True) == {"rondas": 1, "cola": 1}
        assert db.documents[f"agent_runs/{RONDA}_{WEEK}_handoff"]["forced"] is True

    def test_holds_at_night_and_asks_at_nine(self):
        db = ronda()

        assert run(db, at(3, 22)) == {"rondas": 1, "held": 1}
        assert STATE not in db.documents
        assert run(db, at(4, 9)) == {"rondas": 1, "cola": 1}

    def test_a_deadline_passed_at_night_moves_on_at_nine(self):
        db = ronda()
        run(db, at(3, 20))

        assert run(db, at(3, 23)) == {"rondas": 1, "held": 1}
        assert run(db, at(4, 9)) == {"rondas": 1, "members": 1}

    def test_leaves_alone_rondas_that_dont_meet_or_have_no_anfitrion(self):
        db = ronda()
        db.documents["rondas/ended"] = {"status": "ended", "hosts": HOSTS}
        db.documents["rondas/bare"] = {"status": "active", "slot": {"day": "thu"}}

        assert run(db) == {"rondas": 1, "cola": 1}

    def test_a_ronda_claimed_by_another_run_is_left_to_it(self, monkeypatch):
        db = ronda()
        monkeypatch.setattr(handoff, "_claim", lambda ref, state: lambda transaction: False)

        assert run(db) == {"rondas": 1, "already": 1}

    def test_the_claim_is_once(self):
        db = ronda()
        ref = db.document(STATE)

        assert rsvp._in_transaction(db, handoff._claim(ref, {"step": None})) is True
        assert rsvp._in_transaction(db, handoff._claim(ref, {"step": None})) is False
