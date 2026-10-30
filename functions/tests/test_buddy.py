"""The buddy (buddy.py), over the Firestore stand-in. The ronda is the rain check's: Thursday
2026-11-05 at 16:00, four invented members who joined on 2026-10-20. Jorge (demo-102) chose
Mirta (demo-101); at the meeting Jorge, Ana (demo-103, who had said "esta no") and Facu
(demo-104, who chose nobody) were marked [No vino]."""

from datetime import date

import pytest

import buddy
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import HOST, RONDA, WEEK, at, documents
from tests.test_rsvp import Sender

APP = "https://example.test/app/ronda"
FRI_10 = at(6, 10)
DATA = {"rondaId": RONDA}


def ronda() -> FakeFirestore:
    db = FakeFirestore(documents())
    db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["attendance"] = {
        HOST: True,
        "demo-102": False,
        "demo-103": False,
        "demo-104": False,
    }
    db.documents["users/demo-102"]["buddyUid"] = HOST
    return db


def prompt(db, now=FRI_10, sender=None, force=False):
    return buddy.run_prompt_buddy(
        db, now, send=sender if sender is not None else Sender(), app_url=APP, force=force
    )


class TestChoosing:
    def test_is_due_once_a_meeting_passed_since_joining(self):
        db = ronda()

        before = buddy.options(db, "demo-104", DATA, at(5, 12))
        after = buddy.options(db, "demo-104", DATA, FRI_10)

        assert before["due"] is False
        assert after == {
            "due": True,
            "chosen": False,
            "buddyUid": "",
            "buddyName": "",
            "choices": [
                {"uid": "demo-103", "firstName": "Ana"},
                {"uid": "demo-102", "firstName": "Jorge"},
                {"uid": HOST, "firstName": "Mirta"},
            ],
        }

    def test_a_member_who_joined_after_the_meeting_waits_for_the_next(self):
        db = ronda()
        db.documents[f"rondas/{RONDA}/members/demo-104"]["joinedAt"] = at(6, 9)

        assert buddy.options(db, "demo-104", DATA, at(7, 10))["due"] is False

    def test_a_member_with_no_joining_time_counts_every_meeting(self):
        db = ronda()
        del db.documents[f"rondas/{RONDA}/members/demo-104"]["joinedAt"]
        db.documents[f"rondas/{RONDA}/weeks/2026-W44"] = {"rsvp": {}}

        assert buddy.options(db, "demo-104", DATA, FRI_10)["due"] is True

    def test_choosing_someone_and_then_nobody(self):
        db = ronda()

        assert buddy.choose(db, "demo-104", {**DATA, "buddyUid": "demo-103"}) == {
            "buddyUid": "demo-103",
            "buddyName": "Ana",
        }
        chosen = buddy.options(db, "demo-104", DATA, FRI_10)
        assert (chosen["chosen"], chosen["buddyUid"], chosen["buddyName"]) == (
            True,
            "demo-103",
            "Ana",
        )

        assert buddy.choose(db, "demo-104", {**DATA, "buddyUid": ""}) == {
            "buddyUid": "",
            "buddyName": "",
        }
        nobody = buddy.options(db, "demo-104", DATA, FRI_10)
        assert (nobody["chosen"], nobody["buddyUid"]) == (True, "")
        assert db.documents["users/demo-104"]["firstName"] == "Facu"

    def test_a_buddy_who_left_the_ronda_reads_as_nobody(self):
        db = ronda()
        db.documents[f"rondas/{RONDA}/members/{HOST}"]["state"] = "left"

        assert buddy.options(db, "demo-102", DATA, FRI_10)["buddyUid"] == ""

    @pytest.mark.parametrize(
        ("uid", "data", "code"),
        [
            ("demo-104", {}, "invalid-argument"),
            ("demo-104", {"rondaId": "a/b"}, "invalid-argument"),
            ("demo-999", DATA, "permission-denied"),
            ("demo-104", {**DATA, "buddyUid": "demo-104"}, "invalid-argument"),
            ("demo-104", {**DATA, "buddyUid": "demo-999"}, "invalid-argument"),
            ("demo-104", {**DATA, "buddyUid": 7}, "invalid-argument"),
        ],
    )
    def test_refuses(self, uid, data, code):
        db = ronda()

        with pytest.raises(buddy.BuddyError) as excinfo:
            buddy.choose(db, uid, data)
        assert excinfo.value.code == code

    def test_options_are_for_members_only(self):
        with pytest.raises(buddy.BuddyError) as excinfo:
            buddy.options(ronda(), "demo-999", DATA, FRI_10)
        assert excinfo.value.code == "permission-denied"


class TestTheFridayPrompt:
    def test_only_the_buddy_hears_and_only_a_first_name(self):
        db = ronda()
        sender = Sender()

        counts = prompt(db, sender=sender)

        assert counts == {"prompted": 1, "noBuddy": 1, "already": 0, "held": 0}
        assert sender.tokens == [f"tok-{HOST}"]
        data = sender.messages[0]["data"]
        assert data["type"] == "buddy"
        assert data["title"] == "Jorge no vino el jueves"
        assert data["body"].endswith(
            "Jorge no vino el jueves. Te eligió a vos para estas cosas. ¿Le escribís? "
            "Jorge no sabe que te avisamos."
        )
        assert db.documents[f"rondas/{RONDA}/buddy_asks/{HOST}"] == {
            "status": "open",
            "asks": [{"firstName": "Jorge", "day": "thu", "week": WEEK, "at": FRI_10}],
            "updatedAt": FRI_10,
        }
        run = db.documents[f"agent_runs/{RONDA}_{WEEK}_buddy"]
        assert (run["job"], run["model"]) == ("prompt_buddy", "")
        assert not [k for k in db.documents if k.startswith("acta/")]

    def test_a_guest_from_the_bench_who_missed_is_nobodys_to_tell(self):
        db = ronda()
        week = db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]
        week["guests"] = {"demo-900": {"firstName": "Leo", "brings": [], "offerId": "o1"}}
        week["attendance"]["demo-900"] = False
        db.documents["users/demo-900"] = {"firstName": "Leo", "buddyUid": HOST}

        assert prompt(db)["prompted"] == 1

    def test_once_per_miss(self):
        db = ronda()
        prompt(db)

        assert prompt(db, at(6, 11))["already"] == 1

    def test_on_fridays_from_ten_unless_forced(self):
        db = ronda()

        assert prompt(db, at(6, 9))["prompted"] == 0
        assert prompt(db, at(7, 10))["prompted"] == 0
        assert prompt(db, at(5, 20), force=True)["prompted"] == 0
        assert prompt(db, at(6, 9), force=True)["prompted"] == 1

    def test_held_at_night(self):
        assert prompt(ronda(), at(6, 22), force=True)["held"] == 1

    def test_a_paused_member_or_a_meeting_outside_the_week_sends_nothing(self):
        paused = ronda()
        paused.documents[f"rondas/{RONDA}/members/demo-102"].update(
            state="paused", pausedUntil="2026-11-12"
        )
        old = ronda()
        old.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["dateOverride"] = "2026-10-29"
        dateless = ronda()
        del dateless.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["date"]
        ended = ronda()
        ended.documents[f"rondas/{RONDA}"]["status"] = "ended"

        for db in (paused, old, dateless, ended):
            assert prompt(db)["prompted"] == 0

    def test_a_closed_card_starts_a_new_list_and_an_open_one_grows(self):
        db = ronda()
        db.documents["users/demo-104"]["buddyUid"] = HOST
        db.documents[f"rondas/{RONDA}/buddy_asks/{HOST}"] = {"status": "closed", "asks": [{}]}

        assert prompt(db)["prompted"] == 2

        asks = db.documents[f"rondas/{RONDA}/buddy_asks/{HOST}"]["asks"]
        assert [a["firstName"] for a in asks] == ["Jorge", "Facu"]

    def test_missed_reads_only_no_vino_without_esta_no(self):
        members = {"a": {}, "b": {}, "c": {}}
        week = {"attendance": {"a": False, "b": True, "c": False}, "rsvp": {"c": "no"}}

        assert buddy.missed(week, members, date(2026, 11, 5)) == ["a"]
        assert buddy.missed({}, members, date(2026, 11, 5)) == []
