"""seguimos.py with a fixed clock, over the in-memory Firestore stand-in.

The test ronda is a mate ronda in El Pinar sur, Saturday afternoons, six members; its first
meeting is Saturday 2026-10-31 (ISO week 44). The pretext's floor is 4 yeses. After that
meeting the admin may move it to Tuesday, with the RSVP push the day before at 19:00.
"""

from datetime import UTC, date, datetime, timedelta

import pytest

import rsvp
import seguimos
from tests.fake_firestore import FakeFirestore
from tests.test_rsvp import JOINED, RONDA, Sender, at

SATURDAY = date(2026, 10, 31)
ASK = at(31, 20)
UIDS = ("demo-001", "demo-002", "demo-003", "demo-004", "demo-005", "demo-006")
NAMES = ("Marta", "Raúl", "Ana", "Jorge", "Nico", "Lía")


def documents(**ronda_fields) -> dict[str, dict]:
    """The ronda after its first meeting's RSVP push, six active members with one Android
    phone each (demo-001 also has a web one), and the meeting's week document."""
    ronda = {
        "seatId": "el-pinar-sur_mate_sat-afternoon",
        "pretext": "mate",
        "barrio": "el-pinar-sur",
        "slot": {"day": "sat", "time": "afternoon"},
        "size": 6,
        "status": "forming",
        "openSeatFromWeek": 4,
        "createdAt": JOINED,
        **ronda_fields,
    }
    docs = {f"rondas/{RONDA}": ronda}
    for uid, name in zip(UIDS, NAMES, strict=True):
        docs[f"rondas/{RONDA}/members/{uid}"] = {
            "brings": ["pan"] if uid == "demo-001" else [],
            "state": "active",
            "joinedAt": JOINED,
        }
        docs[f"users/{uid}"] = {"firstName": name, "ageBand": "60-69"}
        docs[f"users/{uid}/tokens/tok-{uid[-1]}"] = {"platform": "android"}
        docs[f"users/{uid}/rondas/{RONDA}"] = {"joinedAt": JOINED}
    docs["users/demo-001/tokens/tok-w1"] = {"platform": "web"}
    docs[f"rondas/{RONDA}/weeks/2026-W44"] = {"date": "2026-10-31", "rsvpSentAt": at(29, 19)}
    return docs


def ask(db, now=ASK, sender=None, **kwargs) -> dict:
    return seguimos.run_seguimos_ask(
        db, now, send=sender or Sender(), app_url="https://example.test/app/ronda", **kwargs
    )


def push(db, now, sender=None, **kwargs) -> dict:
    return rsvp.run_rsvp_push(
        db, now, send=sender or Sender(), app_url="https://example.test/app/ronda", **kwargs
    )


AFTER_ASK = at(31, 21)


def answer_all(db, answers: dict[str, str], now=AFTER_ASK) -> None:
    for uid, value in answers.items():
        seguimos.answer(db, uid, RONDA, now, value=value)


def private(db) -> dict:
    return db.documents[f"rondas/{RONDA}/private/seguimos"]


def own(db, uid) -> dict:
    return db.documents[f"rondas/{RONDA}/seguimos/{uid}"]


def counts(db) -> dict:
    return db.documents[f"seguimos_counts/{RONDA}"]


def to_tuesday(db) -> None:
    """The admin's change after meeting 1: Tuesdays, RSVP on Monday at 19:00."""
    db.documents[f"rondas/{RONDA}"]["slot"] = {"day": "tue", "time": "afternoon"}
    db.documents[f"rondas/{RONDA}"]["rsvpLead"] = {"daysBefore": 1, "hour": 19}


MONDAY_19 = at(33, 19)


class TestTime:
    def test_the_first_meeting_is_the_earliest_week_even_after_the_day_changed(self):
        ronda = {"slot": {"day": "tue"}, "createdAt": JOINED}

        assert seguimos.first_meeting(ronda, [date(2026, 11, 3), SATURDAY]) == SATURDAY

    def test_without_weeks_it_is_the_slots_first_day_after_approval(self):
        ronda = {"slot": {"day": "sat"}, "createdAt": JOINED}

        assert seguimos.first_meeting(ronda, []) == SATURDAY
        assert seguimos.first_meeting({"slot": {"day": "sat"}}, []) is None

    def test_asks_at_20_that_day_or_the_next_day_after_an_evening_meeting(self):
        afternoon = {"slot": {"day": "sat", "time": "afternoon"}}
        evening = {"slot": {"day": "sat", "time": "evening"}}

        assert seguimos.ask_due_at(SATURDAY, afternoon) == at(31, 20)
        assert seguimos.ask_due_at(SATURDAY, evening) == at(32, 20)

    def test_a_season_holds_four_meetings_and_the_wait_two_more_weeks(self):
        tuesday = date(2026, 11, 3)

        assert seguimos.season_for(tuesday) == {"start": "2026-11-03", "end": "2026-11-24"}
        assert seguimos.wait_for(tuesday) == {"until": "2026-11-16", "start": "2026-11-17"}

    def test_dates_and_days_read_in_spanish(self):
        assert seguimos.spoken_date(date(2026, 11, 24)) == "martes 24/11"
        assert seguimos.day_plural({"slot": {"day": "sat"}}) == "sábados"
        assert seguimos.day_plural({}) == ""


ALTERNATIVE = {"line": "Jueves a la tarde · truco", "placesLeft": 2}


class TestWords:
    def test_the_season_names_the_day_and_the_end_and_nobody(self):
        ronda = {"slot": {"day": "tue"}}

        assert seguimos.season_words(ronda, seguimos.season_for(date(2026, 11, 3))) == (
            "Seguimos los martes, hasta el martes 24/11. Nadie sabe qué contestó cada uno."
        )

    def test_gracias_lists_the_places_or_says_there_are_none(self):
        one = {**ALTERNATIVE, "placesLeft": 1}

        assert seguimos.gracias_words([ALTERNATIVE, one]) == (
            "Hay lugar cerca: Jueves a la tarde · truco (quedan 2) y "
            "Jueves a la tarde · truco (queda 1). Los ves en Ronda."
        )
        assert seguimos.gracias_words([]).startswith("Por ahora no hay otro grupo")

    def test_didnt_fill_names_the_floor_and_the_wait(self):
        ronda = {"slot": {"day": "tue"}}

        assert seguimos.didnt_fill_words(ronda, 4, seguimos.wait_for(date(2026, 11, 3))) == (
            "Esta vez no llegamos a 4 para seguir los martes. "
            "Elegí en Ronda: sumarte a otro grupo ya, o esperar hasta el lunes 16/11."
        )

    def test_messages_are_data_on_android_a_notification_on_web_and_none_on_iphone(self):
        out = seguimos.messages(
            tokens=[("a", "android"), ("w", "web"), ("i", "ios")],
            kind=seguimos.ASK_TYPE,
            ronda_id=RONDA,
            title="T",
            body="B",
            app_url="https://example.test/app/ronda",
        )

        assert out == [
            {
                "token": "a",
                "data": {"type": "seguimos", "rondaId": RONDA, "title": "T", "body": "B"},
                "android": {"priority": "HIGH"},
            },
            {
                "token": "w",
                "notification": {"title": "T", "body": "B"},
                "webpush": {"fcm_options": {"link": "https://example.test/app/ronda"}},
            },
        ]


class TestAsk:
    def test_before_the_evening_of_the_first_meeting_asks_nobody(self):
        db = FakeFirestore(documents())
        sender = Sender()

        assert ask(db, at(31, 19), sender)["asked"] == 0
        assert sender.messages == []
        assert f"rondas/{RONDA}/private/seguimos" not in db.documents

    def test_asks_every_active_member_privately_once(self):
        docs = documents()
        docs[f"rondas/{RONDA}/members/demo-005"]["state"] = "paused"
        docs[f"rondas/{RONDA}/members/demo-006"]["state"] = "left"
        db = FakeFirestore(docs)
        sender = Sender()

        result = ask(db, ASK, sender)

        assert result == {"asked": 1, "messages": 5, "already": 0, "held": 0, "late": 0}
        assert sender.tokens == ["tok-1", "tok-2", "tok-3", "tok-4", "tok-w1"]
        android = next(m for m in sender.messages if m["token"] == "tok-2")
        assert android["data"] == {
            "type": "seguimos",
            "rondaId": RONDA,
            "title": "Sábado a la tarde · mate en la rambla",
            "body": "¿Seguimos los sábados? Solo Ronda ve tu respuesta. "
            "Nadie del grupo se entera de lo que digas.",
        }
        assert private(db)["asked"] == list(UIDS[:4])
        assert private(db)["firstMeeting"] == "2026-10-31"
        assert own(db, "demo-001") == {"status": "open", "askedAt": ASK}
        assert f"rondas/{RONDA}/seguimos/demo-005" not in db.documents
        assert counts(db)["line"] == "Sábado a la tarde · mate en la rambla"
        assert (counts(db)["yes"], counts(db)["no"], counts(db)["unanswered"]) == (0, 0, 4)

        again = Sender()
        assert ask(db, ASK + timedelta(hours=13), again)["asked"] == 0
        assert again.messages == []

    def test_holds_at_night_and_asks_in_the_morning(self):
        db = FakeFirestore(documents(slot={"day": "sat", "time": "evening"}))

        assert ask(db, at(31, 20))["asked"] == 0
        assert ask(db, at(32, 21))["held"] == 1
        assert ask(db, at(33, 9))["asked"] == 1

    def test_never_asks_once_the_next_meetings_rsvp_went_out(self):
        docs = documents()
        docs[f"rondas/{RONDA}/weeks/2026-W45"] = {
            "date": "2026-11-07",
            "rsvpSentAt": at(5 + 31, 19),
        }
        db = FakeFirestore(docs)
        sender = Sender()

        assert ask(db, at(37, 20), sender)["late"] == 1
        assert sender.messages == []
        assert private(db)["skipped"] == "late"
        assert ask(db, at(37, 20), sender, force=True)["asked"] == 0

    def test_a_week_answered_ahead_without_its_push_doesnt_make_it_late(self):
        docs = documents()
        docs[f"rondas/{RONDA}/weeks/2026-W45"] = {"date": "2026-11-07", "rsvp": {"demo-001": "yes"}}
        db = FakeFirestore(docs)

        assert ask(db)["asked"] == 1

    def test_without_any_week_the_first_meeting_comes_from_the_approval(self):
        docs = {p: d for p, d in documents().items() if "/weeks/" not in p}
        db = FakeFirestore(docs)

        assert ask(db)["asked"] == 1
        assert private(db)["firstMeeting"] == "2026-10-31"

    def test_leaves_rondas_with_a_season_that_dont_meet_or_with_no_first_meeting(self):
        docs = {p: d for p, d in documents().items() if "/weeks/" not in p}
        docs["rondas/with-season"] = {**docs[f"rondas/{RONDA}"], "season": {"start": "x"}}
        docs["rondas/ended"] = {**docs[f"rondas/{RONDA}"], "status": "ended"}
        del docs[f"rondas/{RONDA}"]["createdAt"]
        db = FakeFirestore(docs)

        assert ask(db)["asked"] == 0

    def test_the_admin_can_ask_ahead_but_never_at_night(self):
        db = FakeFirestore(documents())

        assert ask(db, at(30, 22), force=True)["held"] == 1
        assert ask(db, at(30, 12), force=True)["asked"] == 1

    def test_the_mark_is_taken_in_a_transaction(self):
        db = FakeFirestore(documents())
        reference = db.document(f"rondas/{RONDA}/private/seguimos")
        claim = seguimos._claim_ask(reference, ["demo-001"], None, ASK)

        assert rsvp._in_transaction(db, claim) is True
        assert private(db)["firstMeeting"] is None
        assert rsvp._in_transaction(db, claim) is False

    def test_a_ronda_claimed_in_between_counts_as_already(self, monkeypatch):
        db = FakeFirestore(documents())
        monkeypatch.setattr(seguimos, "_claim_ask", lambda *args: lambda transaction: False)

        assert ask(db)["already"] == 1

    def test_takes_the_mark_back_when_sending_fails(self):
        db = FakeFirestore(documents())

        with pytest.raises(ConnectionError):
            ask(db, sender=Sender(error=ConnectionError("fcm down")))
        assert f"rondas/{RONDA}/private/seguimos" not in db.documents
        assert ask(db, ASK + timedelta(minutes=5))["asked"] == 1

    def test_deletes_a_token_fcm_no_longer_knows(self):
        db = FakeFirestore(documents())

        assert ask(db, sender=Sender({"tok-2": "unregistered"}))["messages"] == 6
        assert "users/demo-002/tokens/tok-2" not in db.documents

    def test_a_ronda_with_no_phones_is_asked_without_calling_fcm(self):
        docs = {p: d for p, d in documents().items() if "/tokens/" not in p}
        db = FakeFirestore(docs)

        assert ask(db, sender=Sender(error=AssertionError("not called")))["asked"] == 1


class TestAnswer:
    @pytest.fixture
    def db(self):
        db = FakeFirestore(documents())
        ask(db)
        return db

    @pytest.mark.parametrize(
        ("value", "choice"), [(None, None), ("yes", "join"), ("maybe", None), (None, "later")]
    )
    def test_refuses_anything_but_one_answer_or_one_choice(self, db, value, choice):
        with pytest.raises(seguimos.SeguimosError) as excinfo:
            seguimos.answer(db, "demo-001", RONDA, ASK, value=value, choice=choice)
        assert excinfo.value.code == "invalid-argument"

    def test_refuses_an_unknown_ronda_and_someone_outside_it(self, db):
        with pytest.raises(seguimos.SeguimosError) as excinfo:
            seguimos.answer(db, "demo-001", "nope", ASK, value="yes")
        assert excinfo.value.code == "not-found"
        with pytest.raises(seguimos.SeguimosError) as excinfo:
            seguimos.answer(db, "demo-999", RONDA, ASK, value="yes")
        assert excinfo.value.code == "permission-denied"

    def test_records_the_answer_privately_and_can_change_it_until_the_close(self, db):
        seguimos.answer(db, "demo-002", RONDA, at(31, 21), value="yes")
        result = seguimos.answer(db, "demo-002", RONDA, at(32, 10), value="no")

        assert result == {"answer": "no"}
        assert private(db)["answers"] == {"demo-002": "no"}
        assert own(db, "demo-002")["answer"] == "no"
        assert own(db, "demo-002")["status"] == "open"
        assert (counts(db)["yes"], counts(db)["no"], counts(db)["unanswered"]) == (0, 1, 5)

    def test_someone_not_asked_cannot_answer(self):
        db = FakeFirestore(documents())

        with pytest.raises(seguimos.SeguimosError) as excinfo:
            seguimos.answer(db, "demo-001", RONDA, ASK, value="yes")
        assert excinfo.value.code == "failed-precondition"

    def test_there_is_nothing_to_choose_while_the_question_is_open(self, db):
        with pytest.raises(seguimos.SeguimosError) as excinfo:
            seguimos.answer(db, "demo-001", RONDA, ASK, choice="wait")
        assert excinfo.value.code == "failed-precondition"


class TestClose:
    def test_a_ronda_never_asked_gets_its_usual_push(self):
        db = FakeFirestore(documents())
        to_tuesday(db)
        sender = Sender()

        push(db, MONDAY_19, sender)

        assert len(sender.messages) == 7
        assert "season" not in db.documents[f"rondas/{RONDA}"]

    def test_enough_yeses_start_the_season_with_the_push_and_reopen_the_nos_seats(self):
        db = FakeFirestore(documents())
        ask(db)
        answer_all(db, {"demo-001": "yes", "demo-002": "yes", "demo-003": "yes"})
        answer_all(db, {"demo-004": "yes", "demo-005": "no"})
        to_tuesday(db)
        rsvp.answer(db, "demo-004", RONDA, "yes", at(32, 12))
        sender = Sender()

        result = push(db, MONDAY_19, sender)

        assert result["pushed"] == 1
        ronda = db.documents[f"rondas/{RONDA}"]
        assert ronda["season"] == {"start": "2026-11-03", "end": "2026-11-24"}
        assert ronda["status"] == "active"
        lead = "Seguimos los martes, hasta el martes 24/11. Nadie sabe qué contestó cada uno."
        by_token = {m["token"]: m for m in sender.messages}
        rsvp_push = by_token["tok-1"]["data"]
        assert rsvp_push["type"] == "rsvp"
        assert rsvp_push["title"] == "Martes a la tarde · mate en la rambla"
        assert rsvp_push["body"] == (
            f"{lead} Lugar y hora a confirmar. Ya va Jorge. Te toca llevar el pan. ¿Venís?"
        )
        assert rsvp_push["week"] == "2026-W45"
        assert by_token["tok-w1"]["notification"]["body"].startswith(lead)
        assert by_token["tok-6"]["data"]["type"] == "rsvp"
        assert by_token["tok-4"]["data"] == {
            "type": "seguimosResult",
            "rondaId": RONDA,
            "title": "Martes a la tarde · mate en la rambla",
            "body": lead,
        }
        assert by_token["tok-5"]["data"]["title"] == "Gracias por venir."
        assert by_token["tok-5"]["data"]["type"] == "seguimosResult"
        assert len(sender.messages) == 7

        assert db.documents[f"rondas/{RONDA}/members/demo-005"]["state"] == "left"
        assert own(db, "demo-005")["outcome"] == "gracias"
        assert own(db, "demo-001")["outcome"] == "season"
        assert own(db, "demo-006")["outcome"] == "season"
        assert own(db, "demo-006")["status"] == "closed"
        assert counts(db)["status"] == "season"
        assert (counts(db)["yes"], counts(db)["no"], counts(db)["unanswered"]) == (4, 1, 1)
        view = db.documents[f"rondas/{RONDA}/views/week"]
        assert (view["noCount"], view["unansweredCount"]) == (0, 4)
        assert "demo-005" not in repr(rsvp_push) and "Nico" not in repr(sender.messages)

        with pytest.raises(seguimos.SeguimosError) as excinfo:
            seguimos.answer(db, "demo-005", RONDA, MONDAY_19, value="yes")
        assert excinfo.value.code == "failed-precondition"
        assert seguimos.close(db, RONDA, {}, {}, date(2026, 11, 3), MONDAY_19) is None

    def test_below_the_floor_there_is_no_season_and_everyone_still_in_gets_the_choices(self):
        db = FakeFirestore(documents())
        ask(db)
        answer_all(db, {"demo-001": "yes", "demo-002": "yes", "demo-003": "yes"})
        answer_all(db, {"demo-004": "no"})
        to_tuesday(db)
        sender = Sender()

        push(db, MONDAY_19, sender)

        ronda = db.documents[f"rondas/{RONDA}"]
        assert "season" not in ronda
        assert ronda["status"] == "forming"
        assert {m["data"]["type"] for m in sender.messages if "data" in m} == {"seguimosResult"}
        body = next(m for m in sender.messages if m["token"] == "tok-6")["data"]["body"]
        assert body == (
            "Esta vez no llegamos a 4 para seguir los martes. "
            "Elegí en Ronda: sumarte a otro grupo ya, o esperar hasta el lunes 16/11."
        )
        assert own(db, "demo-006")["outcome"] == "didntFill"
        assert own(db, "demo-006")["wait"] == {"until": "2026-11-16", "start": "2026-11-17"}
        assert own(db, "demo-006")["floor"] == 4
        assert own(db, "demo-004")["outcome"] == "gracias"
        assert counts(db)["status"] == "didntFill"

        result = seguimos.answer(db, "demo-006", RONDA, MONDAY_19, choice="wait")
        seguimos.answer(db, "demo-001", RONDA, MONDAY_19, choice="join")
        seguimos.answer(db, "demo-002", RONDA, MONDAY_19, choice="join")

        assert result == {"choice": "wait"}
        assert own(db, "demo-006")["choice"] == "wait"
        assert private(db)["choices"] == {
            "demo-006": "wait",
            "demo-001": "join",
            "demo-002": "join",
        }
        assert counts(db)["choices"] == {"join": 2, "wait": 1}
        with pytest.raises(seguimos.SeguimosError) as excinfo:
            seguimos.answer(db, "demo-004", RONDA, MONDAY_19, choice="join")
        assert excinfo.value.code == "failed-precondition"

    def test_offers_nearby_rondas_with_places_same_pretext_first_without_their_place(self):
        docs = documents()
        base = {"status": "active", "slot": {"day": "thu", "time": "afternoon"}}
        docs["rondas/near-truco"] = {**base, "pretext": "truco", "barrio": "el-pinar-sur"}
        docs["rondas/norte-mate"] = {
            **base,
            "pretext": "mate",
            "barrio": "el-pinar-norte",
            "place": {"name": "Frente al quiosco"},
        }
        docs["rondas/far"] = {**base, "pretext": "mate", "barrio": "solymar-sur"}
        docs["rondas/full"] = {**base, "pretext": "mate", "barrio": "el-pinar-sur"}
        docs["rondas/ended"] = {
            **base,
            "status": "ended",
            "pretext": "mate",
            "barrio": "el-pinar-sur",
        }
        docs["rondas/nowhere"] = {**base, "pretext": "mate", "barrio": "atlantida"}
        for index in range(6):
            docs[f"rondas/full/members/m{index}"] = {"state": "active"}
        docs["rondas/norte-mate/members/m1"] = {"state": "paused"}
        docs["rondas/norte-mate/members/m2"] = {"state": "left"}
        docs["rondas/norte-mate/members/m3"] = {}
        db = FakeFirestore(docs)
        ronda = docs[f"rondas/{RONDA}"]

        found = seguimos.alternatives(db, RONDA, ronda, date(2026, 11, 2))

        assert [row["rondaId"] for row in found] == ["norte-mate", "near-truco"]
        assert found[0] == {
            "rondaId": "norte-mate",
            "line": "Jueves a la tarde · mate en la rambla",
            "pretext": "mate",
            "barrio": "el-pinar-norte",
            "slot": {"day": "thu", "time": "afternoon"},
            "placesLeft": 5,
            "next": "2026-11-05",
        }
        assert seguimos.alternatives(db, RONDA, {"barrio": "atlantida"}, SATURDAY) == []

    def test_a_no_hears_of_the_nearby_places(self):
        docs = documents()
        docs["rondas/other"] = {
            "status": "active",
            "pretext": "mate",
            "barrio": "el-pinar-norte",
            "slot": {"day": "thu", "time": "afternoon"},
        }
        db = FakeFirestore(docs)
        ask(db)
        answer_all(db, dict.fromkeys(UIDS[:4], "yes") | {"demo-006": "no"})
        to_tuesday(db)
        sender = Sender()

        push(db, MONDAY_19, sender)

        gracias = next(m for m in sender.messages if m["token"] == "tok-6")["data"]["body"]
        assert gracias == (
            "Hay lugar cerca: Jueves a la tarde · mate en la rambla (quedan 6). Los ves en Ronda."
        )
        assert [row["rondaId"] for row in own(db, "demo-006")["alternatives"]] == ["other"]

    def test_closes_once_even_when_another_run_closed_it_in_between(self, monkeypatch):
        db = FakeFirestore(documents())
        ask(db)

        def close_meanwhile(db_, ronda_id, ronda, today):
            private(db)["closedAt"] = MONDAY_19
            return []

        monkeypatch.setattr(seguimos, "alternatives", close_meanwhile)
        members = rsvp._members(db, RONDA)

        assert seguimos.close(db, RONDA, {}, members, date(2026, 11, 3), MONDAY_19) is None

    def test_a_failed_send_after_the_close_takes_the_weeks_mark_back(self):
        db = FakeFirestore(documents())
        ask(db)
        answer_all(db, dict.fromkeys(UIDS[:4], "yes"))
        to_tuesday(db)

        with pytest.raises(ConnectionError):
            push(db, MONDAY_19, Sender(error=ConnectionError("fcm down")))

        assert "rsvpSentAt" not in db.documents[f"rondas/{RONDA}/weeks/2026-W45"]
        assert db.documents[f"rondas/{RONDA}"]["season"]["start"] == "2026-11-03"
        assert push(db, MONDAY_19 + timedelta(hours=1))["pushed"] == 1


def test_a_ronda_from_meeting_one_to_its_season_after_a_day_change():
    """Saturday's meeting, the ask that evening, the admin's move to Tuesday, answers changed
    on Sunday, and Monday's push carries the outcome."""
    docs = documents()
    del docs[f"rondas/{RONDA}/weeks/2026-W44"]
    db = FakeFirestore(docs)
    db.documents[f"rondas/{RONDA}"]["rsvpLead"] = {"daysBefore": 1, "hour": 19}
    assert push(db, at(30, 19))["pushed"] == 1

    assert ask(db, at(31, 19))["asked"] == 0
    assert ask(db, at(31, 20))["asked"] == 1
    to_tuesday(db)
    answer_all(db, dict.fromkeys(UIDS, "yes"), at(31, 21))
    seguimos.answer(db, "demo-006", RONDA, at(32, 11), value="no")
    assert push(db, at(32, 19))["pushed"] == 0

    sender = Sender()
    assert push(db, MONDAY_19, sender)["pushed"] == 1

    assert db.documents[f"rondas/{RONDA}"]["season"] == {"start": "2026-11-03", "end": "2026-11-24"}
    assert db.documents[f"rondas/{RONDA}/weeks/2026-W45"]["date"] == "2026-11-03"
    bodies = {m["token"]: m["data"]["body"] for m in sender.messages if "data" in m}
    assert bodies.pop("tok-6").startswith("Por ahora no hay otro grupo")
    assert all(
        body.startswith("Seguimos los martes, hasta el martes 24/11.") for body in bodies.values()
    )
    assert ask(db, at(33, 20))["asked"] == 0
    assert datetime(2026, 11, 2, 22, tzinfo=UTC) == MONDAY_19
