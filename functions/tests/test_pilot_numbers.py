"""pilot_numbers.py on invented fixtures over the Firestore stand-in. Attendance is written by the
host's "¿Quién vino hoy?" (#47) as `weeks/{isoWeek}.attendance {uid: bool}`; these fixtures use
that exact shape. Uids that don't start with `demo-` play real sign-ups; all are invented."""

from datetime import UTC, date, datetime

import pilot_numbers
from tests.fake_firestore import FakeFirestore
from tests.test_demo_users import on_the_real_project

NOW = datetime(2026, 11, 12, 15, 0, tzinfo=UTC)
JOINED = datetime(2026, 10, 27, 15, 0, tzinfo=UTC)


def member(state="active", joined=JOINED, **more):
    return {"brings": [], "state": state, "joinedAt": joined, **more}


def world() -> dict[str, dict]:
    documents = {
        "rondas/r1": {
            "pretext": "mate",
            "barrio": "el-pinar-sur",
            "slot": {"day": "sat", "time": "afternoon"},
            "status": "active",
        },
        "rondas/r1/members/ana": member(),
        "rondas/r1/members/beto": member(),
        "rondas/r1/members/cora": member("paused", pausedUntil="2026-11-14"),
        "rondas/r1/members/dani": member("left", leftAt=datetime(2026, 11, 5, tzinfo=UTC)),
        "rondas/r1/members/eva": member(joined=datetime(2026, 11, 3, tzinfo=UTC)),
        "rondas/r1/members/demo-001": member(),
        "rondas/r1/weeks/2026-W44": {
            "date": "2026-10-31",
            "rsvp": {"ana": "yes", "beto": "yes", "dani": "no", "demo-001": "yes"},
            "attendance": {"ana": True, "beto": True, "dani": False, "demo-001": True},
        },
        "rondas/r1/weeks/2026-W45": {
            "date": "2026-11-07",
            "rsvp": {"ana": "yes", "eva": "yes"},
            "attendance": {"ana": True, "beto": False, "eva": True},
        },
        "rondas/r1/weeks/2026-W46": {"date": "2026-11-14", "rsvp": {}},
        "seguimos_counts/r1": {
            "status": "season",
            "asked": 4,
            "yes": 3,
            "no": 1,
            "unanswered": 0,
            "line": "x",
        },
        "rondas/demo-ronda": {"pretext": "truco", "slot": {"day": "tue"}, "status": "forming"},
        "rondas/demo-ronda/members/demo-002": member(),
        "rondas/empty": {"pretext": "mate", "slot": {"day": "sat"}, "status": "forming"},
        "rondas/old": {"pretext": "mate", "slot": {"day": "mon"}, "status": "ended"},
        "rondas/old/members/fede": member(),
        "users/hugo": {"terms": {}},
    }
    for uid in ("ana", "beto", "cora", "dani", "eva", "fede", "gabi", "demo-001", "demo-002"):
        documents[f"users/{uid}"] = {"firstName": uid.title(), "terms": {}}
    return documents


class TestNumbers:
    def test_counts_sign_ups_seats_and_each_week_as_x_of_y(self):
        numbers = pilot_numbers.numbers(FakeFirestore(world()), NOW)

        assert numbers["signUps"] == {"profiles": 9, "of": 10}
        assert numbers["seated"] == {"members": 6, "of": 9}
        assert [r["rondaId"] for r in numbers["rondas"]] == ["old", "demo-ronda", "r1"]
        ronda = numbers["rondas"][2]
        assert ronda["line"] == "Sábado a la tarde · mate en la rambla"
        assert (ronda["status"], ronda["members"], ronda["cap"]) == ("active", 5, 6)
        assert ronda["seguimos"] == {
            "asked": 4,
            "yes": 3,
            "no": 1,
            "unanswered": 0,
            "status": "season",
        }
        first, second, third = ronda["weeks"]
        assert first == {
            "week": "2026-W44",
            "date": "2026-10-31",
            "members": 5,
            "yes": 3,
            "no": 2,
            "unanswered": 0,
            "came": 3,
            "marked": 4,
        }
        # Cora is paused until the 14th: no puede on the 7th, sin contestar on the 14th.
        assert (second["members"], second["yes"], second["no"], second["unanswered"]) == (
            5,
            2,
            1,
            2,
        )
        assert (third["came"], third["marked"], third["no"], third["unanswered"]) == (
            None,
            None,
            0,
            5,
        )
        assert ronda["cameBack"] == {"came": 1, "of": 3}
        assert numbers["cameBack"] == {"came": 1, "of": 3}

    def test_on_the_real_project_leaves_the_invented_sign_ups_out(self, monkeypatch):
        on_the_real_project(monkeypatch)

        numbers = pilot_numbers.numbers(FakeFirestore(world()), NOW)

        assert numbers["signUps"] == {"profiles": 7, "of": 8}
        assert [r["rondaId"] for r in numbers["rondas"]] == ["old", "r1"]
        first = numbers["rondas"][1]["weeks"][0]
        assert (first["members"], first["yes"], first["came"], first["marked"]) == (4, 2, 2, 3)
        assert numbers["rondas"][1]["cameBack"] == {"came": 1, "of": 2}

    def test_with_nothing_marked_twice_nobody_came_back_yet(self):
        documents = world()
        del documents["rondas/r1/weeks/2026-W45"]

        numbers = pilot_numbers.numbers(FakeFirestore(documents), NOW)

        assert numbers["cameBack"] is None
        assert numbers["rondas"][2]["cameBack"] is None
        assert numbers["rondas"][0]["seguimos"] is None

    def test_with_nobody_signed_up_everything_is_zero(self):
        assert pilot_numbers.numbers(FakeFirestore(), NOW) == {
            "signUps": {"profiles": 0, "of": 0},
            "seated": {"members": 0, "of": 0},
            "rondas": [],
            "cameBack": None,
        }


class TestWeekMembers:
    def test_without_a_date_counts_everyone_still_in(self):
        members = {"a": member(), "b": member("left")}

        assert list(pilot_numbers.week_members(members, None)) == ["a"]

    def test_someone_who_left_with_no_date_is_out(self):
        members = {"a": member("left"), "b": {"state": "active"}}

        assert list(pilot_numbers.week_members(members, date(2026, 11, 7))) == ["b"]

    def test_a_week_with_no_date_reads_as_the_upcoming_meeting(self):
        week = pilot_numbers.week_numbers("2026-W46", {"rsvp": {"a": "yes"}}, {"a": member()}, NOW)

        assert (week["date"], week["members"], week["yes"]) == (None, 1, 1)
