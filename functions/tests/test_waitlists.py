"""The waiting list's threshold with a deadline and its didn't-fill (waitlists.py), over the
Firestore stand-in. Four invented neighbours wait for mate on Saturday afternoons in El Pinar
Sur; the job first runs on Friday 30/10, so the round ends on Sunday 1/11 and the ronda would
start on Saturday 7/11."""

from datetime import UTC, datetime

import pytest

import jobs
import waitlists
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import at

SEAT = "el-pinar-sur_mate_sat-afternoon"
FRIDAY = at(30, 12, month=10)


def sign_up(uid, *, day, slots=("sat-afternoon",), seats=(SEAT,), pretexts=("mate",)):
    return {
        f"users/{uid}": {
            "firstName": uid.title(),
            "barrio": "el-pinar-sur",
            "pretexts": list(pretexts),
            "slots": list(slots),
            "createdAt": datetime(2026, 10, day, 12, tzinfo=UTC),
        },
        f"users/{uid}/private/eligible": {"seatIds": list(seats)},
    }


def waiting_db(people: int = 4) -> FakeFirestore:
    """`people` neighbours waiting on the Saturday list, plus who doesn't count: Rosa (the seat
    fails her needs filter), Sofi (sits in a ronda), Leo (no known barrio), a sign-up without a
    profile; Juan waits on both the Saturday list and a Sunday one with fewer; and a truco
    ronda nearby with places."""
    docs: dict[str, dict] = {}
    for n in range(people):
        docs |= sign_up(f"demo-50{n}", day=20 + n)
    docs |= sign_up("demo-510", day=1, seats=())
    docs |= sign_up("demo-511", day=1)
    docs["rondas/r-sofi"] = {"status": "active", "slot": {"day": "mon", "time": "morning"}}
    docs["rondas/r-sofi/members/demo-511"] = {"state": "active"}
    docs["rondas/r-sofi/members/demo-500"] = {"state": "left"}
    docs["rondas/r-old"] = {"status": "ended"}
    docs |= sign_up("demo-512", day=1)
    docs["users/demo-512"]["barrio"] = "atlantida"
    docs["users/demo-513"] = {"terms": {}}
    docs |= sign_up(
        "demo-514",
        day=29,
        slots=("sat-afternoon", "sun-morning"),
        seats=(SEAT, "el-pinar-sur_mate_sun-morning"),
    )
    docs["users/demo-514/private/eligible"]["seatIds"].append("el-pinar-sur_truco_sat-afternoon")
    docs["rondas/r-truco"] = {
        "status": "active",
        "pretext": "truco",
        "barrio": "el-pinar-norte",
        "slot": {"day": "thu", "time": "evening"},
    }
    docs["rondas/r-truco/members/demo-520"] = {"state": "active"}
    return FakeFirestore(docs)


def card(db, uid) -> dict:
    return db.documents[f"waiting/{uid}"]


class TestRounds:
    def test_a_round_runs_to_sunday_and_starts_on_the_slot_day_after(self):
        assert waitlists.first_round(FRIDAY.date(), "sat") == {
            "deadline": "2026-11-01",
            "start": "2026-11-07",
        }
        assert waitlists.first_round(at(1, 12).date(), "sun") == {
            "deadline": "2026-11-01",
            "start": "2026-11-08",
        }

    def test_a_round_moves_on_by_weeks(self):
        assert waitlists.later({"deadline": "2026-11-01", "start": "2026-11-07"}, 2) == {
            "deadline": "2026-11-15",
            "start": "2026-11-21",
        }


class TestTheJob:
    def test_counts_who_waits_and_gives_each_their_card(self):
        db = waiting_db()

        counts = waitlists.run_waitlists(db, FRIDAY)

        assert counts == {"lists": 2, "people": 5, "closed": 0, "didntFill": 0}
        row = db.documents[f"waitlists/{SEAT}"]
        assert [e["uid"] for e in row["entries"]] == [
            "demo-500",
            "demo-501",
            "demo-502",
            "demo-503",
            "demo-514",
        ]
        assert row["threshold"] == 6
        assert card(db, "demo-500") | {"updatedAt": None, "alternatives": []} == {
            "seatId": SEAT,
            "barrio": "el-pinar-sur",
            "pretext": "mate",
            "slot": "sat-afternoon",
            "count": 5,
            "threshold": 6,
            "deadline": "2026-11-01",
            "start": "2026-11-07",
            "status": "open",
            "alternatives": [],
            "updatedAt": None,
        }
        [nearby] = card(db, "demo-500")["alternatives"]
        assert nearby["rondaId"] == "r-truco" and nearby["placesLeft"] == 5

    def test_leaves_out_who_doesnt_wait(self):
        db = waiting_db()
        waitlists.run_waitlists(db, FRIDAY)

        cards = {p.split("/")[1] for p in db.documents if p.startswith("waiting/")}
        assert cards == {"demo-500", "demo-501", "demo-502", "demo-503", "demo-514"}

    def test_shows_each_person_the_list_nearest_to_filling(self):
        db = waiting_db()
        waitlists.run_waitlists(db, FRIDAY)

        assert card(db, "demo-514")["seatId"] == SEAT
        assert db.documents["waitlists/el-pinar-sur_mate_sun-morning"]["entries"] == [
            {"uid": "demo-514", "at": datetime(2026, 10, 29, 12, tzinfo=UTC)}
        ]

    def test_the_real_project_leaves_the_invented_sign_ups_out(self, monkeypatch):
        monkeypatch.setenv("GCLOUD_PROJECT", "ronda-uy")
        db = waiting_db()
        db.documents |= sign_up("u-600", day=25)

        waitlists.run_waitlists(db, FRIDAY)

        assert [e["uid"] for e in db.documents[f"waitlists/{SEAT}"]["entries"]] == ["u-600"]

    def test_short_of_the_threshold_at_the_deadline_it_didnt_fill(self):
        db = waiting_db()
        waitlists.run_waitlists(db, FRIDAY)

        counts = waitlists.run_waitlists(db, at(2, 9))

        assert counts["closed"] == 2 and counts["didntFill"] == 2
        mine = card(db, "demo-500")
        assert mine["status"] == "didntFill"
        assert (mine["deadline"], mine["start"]) == ("2026-11-15", "2026-11-21")
        last = db.documents[f"waitlists/{SEAT}"]["last"]
        assert last["outcome"] == "didntFill" and last["deadline"] == "2026-11-01"

    def test_at_the_threshold_it_is_full_and_rolls_a_week(self):
        db = waiting_db(people=6)
        waitlists.run_waitlists(db, FRIDAY)
        assert card(db, "demo-500")["status"] == "full"

        waitlists.run_waitlists(db, at(2, 9))

        assert card(db, "demo-500")["deadline"] == "2026-11-08"
        assert db.documents[f"waitlists/{SEAT}"]["last"]["outcome"] == "full"

    def test_who_is_seated_leaves_and_an_empty_list_goes(self):
        db = waiting_db()
        waitlists.run_waitlists(db, FRIDAY)
        db.documents["rondas/r-sofi/members/demo-514"] = {"state": "active"}

        waitlists.run_waitlists(db, at(31, 12, month=10))

        assert "waitlists/el-pinar-sur_mate_sun-morning" not in db.documents
        assert "waiting/demo-514" not in db.documents

    def test_the_dispatcher_runs_it(self):
        assert "waitlists" in jobs.JOBS
        db = waiting_db()
        assert jobs.run("waitlists", db, FRIDAY, jobs.context())["lists"] == 2


class TestThePick:
    @pytest.fixture
    def didnt_fill(self):
        db = waiting_db()
        waitlists.run_waitlists(db, FRIDAY)
        waitlists.run_waitlists(db, at(2, 9))
        return db

    def test_waiting_two_weeks_more_shows_the_next_dates(self, didnt_fill):
        db = didnt_fill

        result = waitlists.answer(db, "demo-500", "wait", at(2, 10))

        assert result == {"choice": "wait", "start": "2026-11-21", "deadline": "2026-11-15"}
        assert card(db, "demo-500")["status"] == "open"
        waitlists.run_waitlists(db, at(2, 11))
        assert card(db, "demo-500") | {"updatedAt": None} == card(db, "demo-500") | {
            "status": "open",
            "choice": "wait",
            "updatedAt": None,
        }
        assert card(db, "demo-501")["status"] == "didntFill"

    def test_joining_another_ronda_is_recorded_for_the_admin(self, didnt_fill):
        db = didnt_fill

        waitlists.answer(db, "demo-501", "join", at(2, 10))
        waitlists.run_waitlists(db, at(2, 11))

        assert card(db, "demo-501")["status"] == "joined"
        assert db.documents[f"waitlists/{SEAT}"]["choices"] == {"demo-501": "join"}

    def test_the_next_round_asks_again(self, didnt_fill):
        db = didnt_fill
        waitlists.answer(db, "demo-501", "join", at(2, 10))

        waitlists.run_waitlists(db, at(16, 9))

        assert card(db, "demo-501")["status"] == "didntFill"
        assert card(db, "demo-501")["deadline"] == "2026-11-29"

    @pytest.mark.parametrize(
        ("uid", "choice", "code"),
        [
            ("demo-500", "maybe", "invalid-argument"),
            ("demo-999", "wait", "failed-precondition"),
        ],
    )
    def test_refuses_what_it_cannot_record(self, didnt_fill, uid, choice, code):
        with pytest.raises(waitlists.WaitlistError) as excinfo:
            waitlists.answer(didnt_fill, uid, choice, at(2, 10))
        assert excinfo.value.code == code

    def test_cannot_join_with_no_ronda_nearby(self, didnt_fill):
        db = didnt_fill
        db.documents["waiting/demo-500"]["alternatives"] = []

        with pytest.raises(waitlists.WaitlistError) as excinfo:
            waitlists.answer(db, "demo-500", "join", at(2, 10))
        assert excinfo.value.code == "failed-precondition"

    def test_an_open_list_has_nothing_to_choose(self):
        db = waiting_db()
        waitlists.run_waitlists(db, FRIDAY)

        with pytest.raises(waitlists.WaitlistError):
            waitlists.answer(db, "demo-500", "wait", FRIDAY)
