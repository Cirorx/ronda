"""Attendance: the "¿Quién vino hoy?" job and the host's taps (attendance.py), over the Firestore
stand-in. The ronda is the rain check's: Thursday 2026-11-05 at 16:00 in Montevideo, four
invented members, Ana (demo-103) said "esta no"."""

from datetime import date

import pytest

import attendance
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import HOST, RONDA, THURSDAY, WEEK, at, documents
from tests.test_rsvp import Sender

APP = "https://example.test/app/ronda"
THU_17 = at(5, 17)
ROLL = f"rondas/{RONDA}/rolls/{WEEK}"
HOSTS = {"anfitrion": HOST, "cola": "demo-102"}


def ask(db, now=THU_17, sender=None, force=False):
    return attendance.run_attendance_ask(
        db, now, send=sender if sender is not None else Sender(), app_url=APP, force=force
    )


def roll(db) -> dict:
    return db.documents[ROLL]


class TestWhen:
    @pytest.mark.parametrize(
        ("slot", "hour", "minute"),
        [
            ({"day": "thu", "time": "afternoon", "hour": "16:00"}, 17, 0),
            ({"day": "thu", "time": "afternoon", "hour": "16:30"}, 17, 30),
            ({"day": "thu", "time": "evening", "hour": "19:30"}, 20, 0),
            ({"day": "thu", "time": "evening", "hour": "20:00"}, 20, 0),
            ({"day": "thu", "time": "afternoon"}, 17, 0),
            ({"day": "thu", "time": "morning"}, 11, 0),
            ({"day": "thu", "time": "evening"}, 20, 0),
            ({"day": "thu", "time": "late"}, 17, 0),
        ],
    )
    def test_an_hour_in_and_by_20_at_the_latest(self, slot, hour, minute):
        assert attendance.ask_at(THURSDAY, {"slot": slot}) == at(5, hour, minute)

    def test_the_latest_meeting_is_the_last_slot_day(self):
        db = FakeFirestore(documents())
        ronda = db.documents[f"rondas/{RONDA}"]

        assert attendance.latest_meeting(db, RONDA, ronda, date(2026, 11, 7)) == (THURSDAY, WEEK)
        assert attendance.latest_meeting(db, RONDA, ronda, THURSDAY) == (THURSDAY, WEEK)

    def test_a_meeting_the_rain_moved_counts_on_its_new_day(self):
        db = FakeFirestore(documents(hosts=HOSTS))
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["dateOverride"] = "2026-11-06"
        ronda = db.documents[f"rondas/{RONDA}"]

        assert attendance.latest_meeting(db, RONDA, ronda, date(2026, 11, 6)) == (
            date(2026, 11, 6),
            WEEK,
        )
        assert ask(db)["asked"] == 0
        assert ask(db, at(6, 17))["asked"] == 1


class TestTheAsk:
    def test_asks_the_anfitrion_once_an_hour_in_with_the_roll(self):
        db = FakeFirestore(documents(hosts=HOSTS))
        sender = Sender()

        assert ask(db, at(5, 16), sender)["asked"] == 0
        counts = ask(db, sender=sender)

        assert counts == {
            "rondas": 1,
            "asked": 1,
            "noHost": 0,
            "messages": 1,
            "already": 0,
            "held": 0,
        }
        assert sender.tokens == [f"tok-{HOST}"]
        data = sender.messages[0]["data"]
        assert data == {
            "type": "attendance",
            "rondaId": RONDA,
            "week": WEEK,
            "title": "¿Quién vino hoy?",
            "body": "Jueves 16:00 · mate en la rambla · frente al quiosco. Marcá quién vino. "
            "Nadie más ve esta lista.",
        }
        assert roll(db) | {"askedAt": None, "updatedAt": None} == {
            "week": WEEK,
            "date": "2026-11-05",
            "line": "Jueves 16:00 · mate en la rambla · frente al quiosco",
            "hour": "16:00",
            "people": [
                {"uid": "demo-103", "firstName": "Ana"},
                {"uid": "demo-104", "firstName": "Facu"},
                {"uid": "demo-102", "firstName": "Jorge"},
                {"uid": HOST, "firstName": "Mirta"},
            ],
            "marks": {},
            "askedUid": HOST,
            "askedRole": "anfitrion",
            "askedAt": None,
            "updatedAt": None,
        }
        assert ask(db, at(5, 18), sender)["already"] == 1
        assert len(sender.messages) == 1

    def test_the_cola_is_asked_when_the_anfitrion_said_esta_no(self):
        db = FakeFirestore(documents(hosts=HOSTS))
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"][HOST] = "no"

        ask(db)

        assert (roll(db)["askedUid"], roll(db)["askedRole"]) == ("demo-102", "cola")

    def test_who_took_over_opening_that_week_is_asked_first(self):
        opener = {"week": WEEK, "uid": "demo-104", "firstName": "Facu"}
        db = FakeFirestore(documents(hosts=HOSTS, opener=opener))
        last_week = FakeFirestore(documents(hosts=HOSTS, opener={**opener, "week": "2026-W44"}))

        ask(db)
        ask(last_week)

        assert (roll(db)["askedUid"], roll(db)["askedRole"]) == ("demo-104", "opener")
        assert roll(last_week)["askedRole"] == "anfitrion"

    def test_who_is_paused_is_off_the_list_and_cant_be_asked(self):
        db = FakeFirestore(documents(hosts={"anfitrion": HOST}))
        db.documents[f"rondas/{RONDA}/members/{HOST}"] |= {
            "state": "paused",
            "pausedUntil": "2026-11-12",
        }
        db.documents[f"rondas/{RONDA}/members/demo-104"]["state"] = "left"
        sender = Sender()

        counts = ask(db, sender=sender)

        assert counts["noHost"] == 1
        assert sender.messages == []
        assert [p["firstName"] for p in roll(db)["people"]] == ["Ana", "Jorge"]
        assert roll(db)["askedUid"] == ""

    def test_without_hosts_the_roll_waits_for_the_admin(self):
        db = FakeFirestore(documents())

        assert ask(db)["noHost"] == 1
        assert roll(db)["askedRole"] == ""

    def test_skips_rondas_that_dont_meet_today_or_any_more(self):
        db = FakeFirestore(documents(hosts=HOSTS, status="ended"))

        assert ask(db)["rondas"] == 0
        assert ask(FakeFirestore(documents(hosts=HOSTS)), at(4, 17))["asked"] == 0

    def test_holds_in_the_quiet_hours_and_never_writes_the_roll(self):
        db = FakeFirestore(documents(hosts=HOSTS))

        assert ask(db, at(5, 22))["held"] == 1
        assert ROLL not in db.documents

    def test_force_asks_the_latest_meeting_whatever_the_hour(self):
        db = FakeFirestore(documents(hosts=HOSTS))

        assert ask(db, at(7, 10), force=True)["asked"] == 1
        assert roll(db)["date"] == "2026-11-05"

    def test_a_web_phone_opens_the_roll(self):
        db = FakeFirestore(documents(hosts={"anfitrion": "demo-102"}))
        sender = Sender()

        ask(db, sender=sender)

        web = next(m for m in sender.messages if m["token"] == "tok-web")
        assert web["notification"]["title"] == "¿Quién vino hoy?"
        assert web["webpush"]["fcm_options"]["link"] == (
            f"https://example.test/app/asistencia/{RONDA}/{WEEK}"
        )

    def test_an_iphone_gets_nothing_yet(self):
        assert attendance.messages([("t", "ios")], ronda_id="r", week="w", body="b", link="") == []

    def test_a_failed_send_takes_the_roll_back_so_the_next_run_asks(self):
        db = FakeFirestore(documents(hosts=HOSTS))

        with pytest.raises(RuntimeError):
            ask(db, sender=Sender(error=RuntimeError("fcm down")))

        assert ROLL not in db.documents
        assert ask(db, at(5, 18))["asked"] == 1

    def test_a_roll_claimed_in_between_is_left_alone(self, monkeypatch):
        db = FakeFirestore(documents(hosts=HOSTS))
        monkeypatch.setattr(attendance.rsvp, "_in_transaction", lambda db, function: False)

        assert ask(db)["already"] == 1


class TestRecord:
    @pytest.fixture
    def db(self) -> FakeFirestore:
        db = FakeFirestore(documents(hosts=HOSTS))
        ask(db)
        return db

    def tap(self, db, caller=HOST, admin=False, now=THU_17, **fields):
        data = {"rondaId": RONDA, "week": WEEK, "uid": "demo-104", "came": True, **fields}
        return attendance.record(db, caller, admin, data, now)

    def test_a_tap_writes_the_record_and_the_hosts_copy(self, db):
        assert self.tap(db) == {"week": WEEK, "uid": "demo-104", "came": True}
        self.tap(db, uid="demo-103", came=False)

        record = db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]
        assert record["attendance"] == {"demo-104": True, "demo-103": False}
        assert record["rsvp"]["demo-101"] == "yes"
        assert roll(db)["marks"] == {"demo-104": True, "demo-103": False}

    def test_a_tap_can_be_corrected(self, db):
        self.tap(db)
        self.tap(db, came=False)

        assert roll(db)["marks"] == {"demo-104": False}

    def test_the_cola_and_the_admin_record_it_too(self, db):
        self.tap(db, caller="demo-102")
        self.tap(db, caller="demo-admin", admin=True, uid="demo-103")

        assert roll(db)["marks"] == {"demo-104": True, "demo-103": True}

    def test_the_host_it_was_sent_to_keeps_it_after_the_hosts_change(self, db):
        db.documents[f"rondas/{RONDA}"]["hosts"] = {"anfitrion": "demo-104"}

        assert self.tap(db)["came"] is True

    @pytest.mark.parametrize(
        ("caller", "state"),
        [("demo-104", "active"), ("demo-102", "left"), ("demo-102", None)],
    )
    def test_nobody_else_records_it(self, db, caller, state):
        member = f"rondas/{RONDA}/members/demo-102"
        if state is None:
            del db.documents[member]
        else:
            db.documents[member]["state"] = state

        with pytest.raises(attendance.AttendanceError) as excinfo:
            self.tap(db, caller=caller)
        assert excinfo.value.code == "permission-denied"

    @pytest.mark.parametrize(
        ("fields", "code"),
        [
            ({"rondaId": ""}, "invalid-argument"),
            ({"week": "a/b"}, "invalid-argument"),
            ({"uid": 3}, "invalid-argument"),
            ({"came": "yes"}, "invalid-argument"),
            ({"uid": "demo-999"}, "invalid-argument"),
            ({"week": "2026-W46"}, "not-found"),
        ],
    )
    def test_refuses_what_isnt_a_tap_on_the_roll(self, db, fields, code):
        with pytest.raises(attendance.AttendanceError) as excinfo:
            self.tap(db, **fields)
        assert excinfo.value.code == code

    def test_refuses_a_body_that_isnt_an_object(self, db):
        with pytest.raises(attendance.AttendanceError):
            attendance.record(db, HOST, False, None, THU_17)

    def test_until_six_days_after_the_meeting(self, db):
        assert self.tap(db, now=at(11, 20))["came"] is True

        with pytest.raises(attendance.AttendanceError) as excinfo:
            self.tap(db, now=at(12, 9))
        assert excinfo.value.code == "failed-precondition"

    def test_the_claim_refuses_a_roll_that_is_there(self):
        db = FakeFirestore({ROLL: {"week": WEEK}})

        assert attendance._claim(db.document(ROLL), {"week": "other"})(db.transaction()) is False
        assert roll(db) == {"week": WEEK}
