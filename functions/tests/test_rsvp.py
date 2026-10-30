"""rsvp.py with a fixed clock, over the in-memory Firestore stand-in.

The test ronda meets on Saturday 2026-10-31 in the afternoon (ISO week 44); Montevideo is UTC-3.
"""

from datetime import UTC, date, datetime, timedelta

import pytest

import rsvp
from tests.fake_firestore import FakeFirestore

RONDA = "ronda-1"
JOINED = datetime(2026, 10, 27, 15, 0, tzinfo=UTC)


def at(day: int, hour: int, minute: int = 0) -> datetime:
    """`day` October 2026 (or November past 31) at `hour`:`minute` in Montevideo, as UTC."""
    local = datetime(2026, 10, 1, hour, minute, tzinfo=rsvp.MONTEVIDEO) + timedelta(days=day - 1)
    return local.astimezone(UTC)


THU_19 = at(29, 19)
SATURDAY = date(2026, 10, 31)


def documents(**ronda_fields) -> dict[str, dict]:
    """A ronda the way approve_proposal writes it, three members, and their phones."""
    ronda = {
        "seatId": "el-pinar-sur_mate_sat-afternoon",
        "pretext": "mate",
        "barrio": "el-pinar-sur",
        "slot": {"day": "sat", "time": "afternoon"},
        "size": 3,
        "status": "forming",
        "openSeatFromWeek": 4,
        "createdAt": JOINED,
        **ronda_fields,
    }
    members = {"demo-001": ["pan"], "demo-002": ["termo", "pan"], "demo-003": ["tengo-ganas"]}
    names = {"demo-001": "Marta", "demo-002": "Raúl", "demo-003": "Ana"}
    docs = {f"rondas/{RONDA}": ronda}
    for uid, brings in members.items():
        docs[f"rondas/{RONDA}/members/{uid}"] = {
            "brings": brings,
            "state": "active",
            "joinedAt": JOINED,
        }
        docs[f"users/{uid}"] = {"firstName": names[uid], "ageBand": "60-69"}
    docs["users/demo-001/tokens/tok-a1"] = {"platform": "android"}
    docs["users/demo-001/tokens/tok-w1"] = {"platform": "web"}
    docs["users/demo-002/tokens/tok-a2"] = {"platform": "android"}
    docs["users/demo-003/tokens/tok-i3"] = {"platform": "ios"}
    return docs


class Sender:
    """Stands in for fcm.send: keeps every message, answers `ok` unless told otherwise."""

    def __init__(self, outcomes: dict[str, str] | None = None, error: Exception | None = None):
        self.messages: list[dict] = []
        self._outcomes = outcomes or {}
        self._error = error

    def __call__(self, messages: list[dict]) -> list[str]:
        if self._error:
            raise self._error
        self.messages.extend(messages)
        return [self._outcomes.get(m["token"], "ok") for m in messages]

    @property
    def tokens(self) -> list[str]:
        return sorted(m["token"] for m in self.messages)


def week_doc(db: FakeFirestore, week: str = "2026-W44") -> dict:
    return db.documents.get(f"rondas/{RONDA}/weeks/{week}", {})


def view(db: FakeFirestore) -> dict:
    return db.documents[f"rondas/{RONDA}/views/week"]


class TestTime:
    def test_the_week_is_the_meetings_iso_week(self):
        assert rsvp.iso_week(SATURDAY) == "2026-W44"
        assert rsvp.iso_week(date(2026, 11, 2)) == "2026-W45"
        assert rsvp.iso_week(date(2027, 1, 1)) == "2026-W53"

    @pytest.mark.parametrize(
        ("day", "today", "meeting"),
        [
            ("sat", date(2026, 10, 29), SATURDAY),
            ("sat", SATURDAY, SATURDAY),
            ("thu", date(2026, 10, 30), date(2026, 11, 5)),
            ("mon", SATURDAY, date(2026, 11, 2)),
        ],
    )
    def test_the_next_meeting_is_on_or_after_today(self, day, today, meeting):
        assert rsvp.next_meeting(day, today) == meeting

    @pytest.mark.parametrize(
        ("value", "expected"),
        [
            (None, {"daysBefore": 2, "hour": 19}),
            ("friday", {"daysBefore": 2, "hour": 19}),
            ({"daysBefore": 1, "hour": 19}, {"daysBefore": 1, "hour": 19}),
            ({"daysBefore": 6, "hour": 9}, {"daysBefore": 6, "hour": 9}),
            ({"daysBefore": 0, "hour": 22}, {"daysBefore": 2, "hour": 19}),
            ({"daysBefore": 7, "hour": 8}, {"daysBefore": 2, "hour": 19}),
            ({"daysBefore": "1", "hour": "19"}, {"daysBefore": 2, "hour": 19}),
        ],
    )
    def test_the_lead_time_defaults_to_two_days_before_at_19(self, value, expected):
        ronda = {} if value is None else {"rsvpLead": value}

        assert rsvp.lead(ronda) == expected

    def test_a_saturday_ronda_can_take_it_on_friday(self):
        assert rsvp.push_due_at(SATURDAY, {}) == at(29, 19)
        assert rsvp.push_due_at(SATURDAY, {"rsvpLead": {"daysBefore": 1, "hour": 19}}) == at(30, 19)

    @pytest.mark.parametrize(
        ("now", "inside"),
        [(at(29, 9), True), (at(29, 20, 59), True), (at(29, 21), False), (at(29, 8, 59), False)],
    )
    def test_the_gate_is_09_to_21_in_montevideo(self, now, inside):
        assert rsvp.inside_gate(now) is inside


PAUSE_MEMBERS = {
    "a": {"brings": ["pan"], "state": "active"},
    "b": {"brings": ["termo"], "state": "active"},
    "c": {"brings": [], "state": "active"},
    "d": {"brings": [], "state": "paused", "pausedUntil": "2026-11-14"},
    "e": {"brings": [], "state": "left"},
    "f": {"brings": ["yerba"], "state": "paused", "pausedUntil": "2026-10-31"},
}
PAUSE_NAMES = {"a": "Marta", "b": "Ana", "c": "Raúl", "d": "Facu", "f": "Jorge"}


class TestWeekView:
    def test_shows_the_yeses_by_first_name_and_only_counts_the_rest(self):
        rsvp_map = {"a": "yes", "b": "yes", "c": "no", "e": "yes"}

        result = rsvp.week_view(SATURDAY, PAUSE_MEMBERS, PAUSE_NAMES, rsvp_map, THU_19)

        assert result == {
            "week": "2026-W44",
            "date": "2026-10-31",
            "going": [
                {"uid": "b", "firstName": "Ana", "brings": ["termo"]},
                {"uid": "a", "firstName": "Marta", "brings": ["pan"]},
            ],
            "noCount": 2,
            "unansweredCount": 1,
            "updatedAt": THU_19,
        }

    def test_a_pause_ending_on_the_meeting_counts_as_back(self):
        result = rsvp.week_view(SATURDAY, PAUSE_MEMBERS, PAUSE_NAMES, {}, THU_19)

        assert (result["noCount"], result["unansweredCount"]) == (1, 4)

    def test_a_paused_member_who_says_yes_is_going(self):
        result = rsvp.week_view(SATURDAY, PAUSE_MEMBERS, PAUSE_NAMES, {"d": "yes"}, THU_19)

        assert [p["firstName"] for p in result["going"]] == ["Facu"]
        assert result["noCount"] == 0


class TestPushText:
    def test_the_line_is_the_day_band_and_pretext(self):
        assert rsvp.ronda_line(documents()[f"rondas/{RONDA}"]) == (
            "Sábado a la tarde · mate en la rambla"
        )

    def test_the_line_names_a_public_place_and_never_an_address(self):
        ronda = {
            "pretext": "truco",
            "slot": {"day": "tue", "time": "evening"},
            "place": {"name": "Club Lagomar", "address": "Av. Central 1234"},
            "despues": {"kind": "home", "label": "lo de Mirta", "address": "Calle 5 678"},
        }

        line = rsvp.ronda_line(ronda)

        assert line == "Martes a la noche · truco · Club Lagomar"
        assert "1234" not in line and "678" not in line

    def test_the_line_says_the_hour_and_the_place_once_set(self):
        ronda = documents(
            slot={"day": "sat", "time": "afternoon", "hour": "16:30"},
            place={"name": "frente al quiosco", "landmark": "al lado de la parada"},
        )[f"rondas/{RONDA}"]

        assert rsvp.ronda_line(ronda) == "Sábado 16:30 · mate en la rambla · frente al quiosco"
        assert rsvp.to_confirm(ronda) == ""

    @pytest.mark.parametrize(
        ("fields", "words"),
        [
            ({}, "Lugar y hora a confirmar."),
            ({"place": {"name": "la plaza"}}, "Hora a confirmar."),
            ({"place": {"name": ""}}, "Lugar y hora a confirmar."),
            ({"slot": {"day": "sat", "time": "afternoon", "hour": "16:00"}}, "Lugar a confirmar."),
        ],
    )
    def test_what_isnt_set_yet_is_said_not_invented(self, fields, words):
        assert rsvp.to_confirm(documents(**fields)[f"rondas/{RONDA}"]) == words

    @pytest.mark.parametrize(
        ("hour", "band", "fits"),
        [
            ("09:00", "morning", True),
            ("11:00", "morning", True),
            ("11:30", "morning", False),
            ("16:30", "afternoon", True),
            ("13:30", "afternoon", False),
            ("20:00", "evening", True),
            ("20:30", "evening", False),
            ("9:00", "morning", False),
            ("16h", "afternoon", False),
            (16, "afternoon", False),
            ("16:00", "night", False),
        ],
    )
    def test_an_hour_fits_its_band_with_the_meeting_inside(self, hour, band, fits):
        assert rsvp.hour_in_band(hour, band) is fits

    def test_an_hour_outside_its_band_is_no_hour(self):
        ronda = {"slot": {"day": "sat", "time": "morning", "hour": "16:00"}}

        assert rsvp.meeting_hour(ronda) is None

    def test_the_body_opens_with_what_is_still_to_confirm(self):
        assert rsvp.push_body(["Marta"], [], unknown="Hora a confirmar.") == (
            "Hora a confirmar. Ya va Marta. ¿Venís?"
        )

    def test_the_line_keeps_an_unknown_pretext_id(self):
        assert rsvp.ronda_line({"pretext": "bochas", "slot": {}}) == "bochas"

    @pytest.mark.parametrize(
        ("names", "brings", "body"),
        [
            ([], ["pan"], "Te toca llevar el pan. ¿Venís?"),
            ([], ["tengo-ganas", "termo"], "Te toca llevar el termo. ¿Venís?"),
            ([], ["tengo-ganas"], "¿Venís?"),
            (["Marta"], [], "Ya va Marta. ¿Venís?"),
            (["Marta", "Raúl"], ["sillas"],
             "Ya van Marta y Raúl. Te toca llevar las sillas. ¿Venís?"),
            (["A", "B", "C"], ["enseno-truco"], "Ya van A, B y C. Te toca enseñar truco. ¿Venís?"),
            (["A", "B", "C", "D", "E", "F"], ["yerba"],
             "Ya van A, B, C, D y 2 más. Te toca llevar la yerba. ¿Venís?"),
        ],
    )  # fmt: skip
    def test_the_body_says_who_goes_what_you_bring_and_asks(self, names, brings, body):
        assert rsvp.push_body(names, brings) == body

    def test_android_gets_data_only_at_high_priority_and_web_a_plain_notification(self):
        messages = rsvp.rsvp_messages(
            tokens=[("t-a", "android"), ("t-w", "web"), ("t-i", "ios"), ("t-x", "")],
            title="Sábado a la tarde · mate en la rambla",
            body="¿Venís?",
            ronda_id=RONDA,
            week="2026-W44",
            app_url="https://ronda-uy.firebaseapp.com/app/ronda",
        )

        assert messages == [
            {
                "token": "t-a",
                "data": {
                    "type": "rsvp",
                    "rondaId": RONDA,
                    "week": "2026-W44",
                    "title": "Sábado a la tarde · mate en la rambla",
                    "body": "¿Venís?",
                },
                "android": {"priority": "HIGH"},
            },
            {
                "token": "t-w",
                "notification": {
                    "title": "Sábado a la tarde · mate en la rambla",
                    "body": "¿Venís?",
                },
                "webpush": {"fcm_options": {"link": "https://ronda-uy.firebaseapp.com/app/ronda"}},
            },
        ]


class TestAnswer:
    def test_records_the_answer_the_view_and_the_members_own_answer(self):
        db = FakeFirestore(documents())

        result = rsvp.answer(db, "demo-001", RONDA, "yes", THU_19)

        assert result == {"week": "2026-W44", "answer": "yes"}
        assert week_doc(db) == {"date": "2026-10-31", "rsvp": {"demo-001": "yes"}}
        assert view(db)["going"] == [{"uid": "demo-001", "firstName": "Marta", "brings": ["pan"]}]
        assert (view(db)["noCount"], view(db)["unansweredCount"]) == (0, 2)
        assert db.documents[f"rondas/{RONDA}/answers/demo-001"] == {
            "week": "2026-W44",
            "answer": "yes",
            "at": THU_19,
        }

    def test_two_members_answering_both_count_and_a_change_moves_the_count(self):
        db = FakeFirestore(documents())

        rsvp.answer(db, "demo-001", RONDA, "yes", THU_19)
        rsvp.answer(db, "demo-002", RONDA, "no", THU_19)
        rsvp.answer(db, "demo-001", RONDA, "no", THU_19 + timedelta(minutes=5))

        assert week_doc(db)["rsvp"] == {"demo-001": "no", "demo-002": "no"}
        assert view(db)["going"] == []
        assert (view(db)["noCount"], view(db)["unansweredCount"]) == (2, 1)

    def test_keeps_the_push_mark_on_the_week(self):
        db = FakeFirestore(documents())
        db.documents[f"rondas/{RONDA}/weeks/2026-W44"] = {
            "date": "2026-10-31",
            "rsvpSentAt": THU_19,
        }

        rsvp.answer(db, "demo-002", RONDA, "yes", THU_19)

        assert week_doc(db)["rsvpSentAt"] == THU_19

    def test_on_the_meeting_day_it_answers_that_days_meeting(self):
        db = FakeFirestore(documents())

        assert rsvp.answer(db, "demo-001", RONDA, "no", at(31, 10))["week"] == "2026-W44"

    def test_takes_the_push_week_while_it_is_still_the_upcoming_one(self):
        db = FakeFirestore(documents())

        assert rsvp.answer(db, "demo-001", RONDA, "yes", THU_19, week="2026-W44")

    def test_refuses_an_old_notifications_week(self):
        db = FakeFirestore(documents())

        with pytest.raises(rsvp.RsvpError) as excinfo:
            rsvp.answer(db, "demo-001", RONDA, "yes", at(32, 10), week="2026-W44")
        assert excinfo.value.code == "failed-precondition"
        assert not week_doc(db, "2026-W45")

    @pytest.mark.parametrize(
        ("uid", "ronda_id", "value", "pause", "code"),
        [
            ("demo-001", RONDA, "maybe", None, "invalid-argument"),
            ("demo-001", RONDA, None, None, "invalid-argument"),
            ("demo-001", RONDA, "yes", 2, "invalid-argument"),
            ("demo-001", RONDA, "no", 3, "invalid-argument"),
            ("demo-001", RONDA, "no", "2", "invalid-argument"),
            ("demo-001", "other", "yes", None, "not-found"),
            ("demo-999", RONDA, "yes", None, "permission-denied"),
            ("demo-left", RONDA, "yes", None, "permission-denied"),
        ],
    )
    def test_refuses(self, uid, ronda_id, value, pause, code):
        docs = documents()
        docs[f"rondas/{RONDA}/members/demo-left"] = {"brings": [], "state": "left"}
        db = FakeFirestore(docs)

        with pytest.raises(rsvp.RsvpError) as excinfo:
            rsvp.answer(db, uid, ronda_id, value, THU_19, pause_weeks=pause)
        assert excinfo.value.code == code
        assert not week_doc(db)

    def test_pausing_two_weeks_says_no_and_pauses_through_the_meeting_after_next(self):
        db = FakeFirestore(documents())

        rsvp.answer(db, "demo-002", RONDA, "no", THU_19, pause_weeks=2)

        member = db.documents[f"rondas/{RONDA}/members/demo-002"]
        assert (member["state"], member["pausedUntil"]) == ("paused", "2026-11-14")
        assert week_doc(db)["rsvp"] == {"demo-002": "no"}
        assert view(db)["noCount"] == 1

    def test_a_yes_ends_a_pause(self):
        db = FakeFirestore(documents())
        rsvp.answer(db, "demo-002", RONDA, "no", THU_19, pause_weeks=2)

        rsvp.answer(db, "demo-002", RONDA, "yes", THU_19)

        member = db.documents[f"rondas/{RONDA}/members/demo-002"]
        assert member["state"] == "active"
        assert "pausedUntil" not in member
        assert [p["uid"] for p in view(db)["going"]] == ["demo-002"]

    def test_a_member_without_a_profile_shows_with_no_name(self):
        docs = documents()
        del docs["users/demo-003"]
        db = FakeFirestore(docs)

        rsvp.answer(db, "demo-003", RONDA, "yes", THU_19)

        assert view(db)["going"] == [
            {"uid": "demo-003", "firstName": "", "brings": ["tengo-ganas"]}
        ]


class TestRunRsvpPush:
    def run(self, db, now, sender=None, **kwargs):
        return rsvp.run_rsvp_push(
            db, now, send=sender or Sender(), app_url="https://example.test/app/ronda", **kwargs
        )

    def test_before_the_lead_time_sends_nothing_but_keeps_the_view_on_the_meeting(self):
        db = FakeFirestore(documents())
        sender = Sender()

        counts = self.run(db, at(29, 18), sender)

        assert sender.messages == []
        assert counts == {"rondas": 1, "pushed": 0, "messages": 0, "already": 0, "held": 0}
        assert view(db)["week"] == "2026-W44"
        assert view(db)["unansweredCount"] == 3
        assert "rsvpSentAt" not in week_doc(db)

    def test_at_the_lead_time_sends_each_member_on_each_phone_once(self):
        db = FakeFirestore(documents())
        sender = Sender()

        counts = self.run(db, THU_19, sender)

        assert sender.tokens == ["tok-a1", "tok-a2", "tok-w1"]
        assert counts == {"rondas": 1, "pushed": 1, "messages": 3, "already": 0, "held": 0}
        assert week_doc(db)["rsvpSentAt"] == THU_19
        android = next(m for m in sender.messages if m["token"] == "tok-a2")
        assert android["data"]["title"] == "Sábado a la tarde · mate en la rambla"
        assert android["data"]["body"] == (
            "Lugar y hora a confirmar. Te toca llevar el termo. ¿Venís?"
        )
        assert android["data"]["week"] == "2026-W44"
        web = next(m for m in sender.messages if m["token"] == "tok-w1")
        assert web["webpush"]["fcm_options"]["link"] == "https://example.test/app/ronda"

    def test_a_second_run_in_the_same_week_sends_nothing(self):
        db = FakeFirestore(documents())
        self.run(db, THU_19)
        sender = Sender()

        counts = self.run(db, THU_19 + timedelta(hours=1), sender, force=True)

        assert sender.messages == []
        assert counts["already"] == 1

    def test_a_saturday_ronda_set_to_friday_waits_for_friday(self):
        db = FakeFirestore(documents(rsvpLead={"daysBefore": 1, "hour": 19}))
        sender = Sender()

        self.run(db, THU_19, sender)
        assert sender.messages == []

        self.run(db, at(30, 19), sender)
        assert len(sender.messages) == 3

    def test_holds_at_night_and_catches_up_in_the_morning(self):
        db = FakeFirestore(documents())
        sender = Sender()

        counts = self.run(db, at(29, 21, 30), sender)
        assert (counts["held"], sender.messages) == (1, [])
        assert "rsvpSentAt" not in week_doc(db)

        counts = self.run(db, at(30, 9), sender)
        assert (counts["pushed"], len(sender.messages)) == (1, 3)

    def test_never_on_the_meeting_day_unless_the_admin_forces_it(self):
        db = FakeFirestore(documents())
        sender = Sender()

        self.run(db, at(31, 10), sender)
        assert sender.messages == []

        self.run(db, at(31, 10), sender, force=True)
        assert len(sender.messages) == 3

    def test_force_sends_ahead_of_the_lead_time_but_never_at_night(self):
        db = FakeFirestore(documents())
        sender = Sender()

        assert self.run(db, at(28, 22), sender, force=True)["held"] == 1
        assert self.run(db, at(28, 15), sender, force=True)["pushed"] == 1
        assert len(sender.messages) == 3

    def test_skips_who_answered_who_paused_and_who_left_and_names_the_yeses(self):
        docs = documents()
        docs[f"rondas/{RONDA}/members/demo-003"]["state"] = "left"
        docs[f"rondas/{RONDA}/members/demo-004"] = {
            "brings": [],
            "state": "paused",
            "pausedUntil": "2026-11-07",
        }
        docs["users/demo-004/tokens/tok-a4"] = {"platform": "android"}
        db = FakeFirestore(docs)
        rsvp.answer(db, "demo-001", RONDA, "yes", at(28, 12))
        sender = Sender()

        self.run(db, THU_19, sender)

        assert sender.tokens == ["tok-a2"]
        assert sender.messages[0]["data"]["body"] == (
            "Lugar y hora a confirmar. Ya va Marta. Te toca llevar el termo. ¿Venís?"
        )

    def test_a_monday_meeting_pushed_on_saturday_belongs_to_the_meetings_week(self):
        docs = documents(slot={"day": "mon", "time": "evening"})
        db = FakeFirestore(docs)
        sender = Sender()

        self.run(db, at(31, 19), sender)

        assert {m["data"]["week"] for m in sender.messages if "data" in m} == {"2026-W45"}
        assert week_doc(db, "2026-W45")["date"] == "2026-11-02"

    def test_deletes_a_token_fcm_no_longer_knows(self):
        db = FakeFirestore(documents())

        counts = self.run(db, THU_19, Sender({"tok-a2": "unregistered", "tok-w1": "failed"}))

        assert counts["messages"] == 1
        assert "users/demo-002/tokens/tok-a2" not in db.documents
        assert "users/demo-001/tokens/tok-w1" in db.documents

    def test_takes_the_mark_back_when_sending_fails_so_the_next_run_tries_again(self):
        db = FakeFirestore(documents())

        with pytest.raises(ConnectionError):
            self.run(db, THU_19, Sender(error=ConnectionError("fcm down")))
        assert "rsvpSentAt" not in week_doc(db)

        assert self.run(db, THU_19 + timedelta(hours=1))["pushed"] == 1

    def test_a_ronda_with_no_phones_counts_as_pushed_without_calling_fcm(self):
        docs = {p: d for p, d in documents().items() if "/tokens/" not in p}
        db = FakeFirestore(docs)
        sender = Sender(error=AssertionError("not called"))

        assert self.run(db, THU_19, sender)["pushed"] == 1

    def test_leaves_rondas_that_dont_meet(self):
        docs = documents(status="ended")
        db = FakeFirestore(docs)

        assert self.run(db, THU_19)["rondas"] == 0
        assert f"rondas/{RONDA}/views/week" not in db.documents

    def test_moves_the_view_to_the_next_meeting_once_and_keeps_early_answers(self):
        db = FakeFirestore(documents())
        self.run(db, at(29, 10))
        first = view(db)
        self.run(db, at(29, 11))
        assert view(db)["updatedAt"] == first["updatedAt"]

        db.documents[f"rondas/{RONDA}/weeks/2026-W45"] = {"rsvp": {"demo-003": "yes"}}
        self.run(db, at(32, 10))

        assert view(db)["week"] == "2026-W45"
        assert [p["uid"] for p in view(db)["going"]] == ["demo-003"]

    def test_never_puts_an_address_in_a_push(self):
        db = FakeFirestore(
            documents(
                place={"name": "Frente al quiosco", "address": "Av. Central 1234"},
                despues={"kind": "home", "label": "lo de Mirta", "address": "Calle 5 678"},
            )
        )
        sender = Sender()

        self.run(db, THU_19, sender)

        assert sender.messages
        assert "1234" not in repr(sender.messages) and "678" not in repr(sender.messages)
