"""The monthly turns of who opens and who closes (rotation.py), over the Firestore stand-in. The
ronda is the rain check's four invented members, who joined in this order: Mirta (demo-101),
Jorge (demo-102), Ana (demo-103), Facu (demo-104)."""

import pytest

import rotation
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import HOST, RONDA, at, documents

NOV_1 = at(1, 0)
CYCLE = ["demo-101", "demo-102", "demo-103", "demo-104"]


def ronda(month: str | None = "2026-10", **hosts) -> FakeFirestore:
    chosen = {"anfitrion": HOST, "cola": "demo-102", **hosts}
    if month:
        chosen["month"] = month
    return FakeFirestore(documents(hosts=chosen))


def pairs(db) -> list[tuple[str, str, str]]:
    turns = db.documents[f"rondas/{RONDA}"]["turns"]
    return [(t["month"], t["anfitrionName"], t["colaName"]) for t in turns]


class TestTheRule:
    def test_months(self):
        assert rotation.month_of(at(30, 23, month=10)) == "2026-10"
        assert rotation.month_of(at(1, 0)) == "2026-11"
        assert rotation.add_months("2026-11", 2) == "2027-01"
        assert rotation.add_months("2027-01", -1) == "2026-12"

    def test_the_cycle_is_the_active_members_by_when_they_joined(self):
        members = {
            "b": {"state": "active", "joinedAt": "2"},
            "a": {"state": "active", "joinedAt": "1"},
            "p": {"state": "paused", "joinedAt": "0"},
            "c": {"joinedAt": "3"},
        }

        assert rotation.cycle(members) == ["a", "b", "c"]

    @pytest.mark.parametrize(
        ("pair", "following"),
        [
            (("demo-101", "demo-102"), ("demo-102", "demo-103")),
            (("demo-103", "demo-104"), ("demo-104", "demo-101")),
            (("demo-102", "gone"), ("demo-103", "demo-104")),
            (("gone", "also-gone"), ("demo-101", "demo-102")),
        ],
    )
    def test_the_cola_opens_next_month_and_the_next_one_closes(self, pair, following):
        assert rotation.next_pair(CYCLE, pair) == following

    def test_with_fewer_than_two_the_pair_stays(self):
        assert rotation.next_pair(["demo-101"], ("demo-101", "demo-102")) == (
            "demo-101",
            "demo-102",
        )


class TestTheJob:
    def test_a_new_month_moves_the_turn_and_says_so_in_the_acta(self):
        db = ronda()

        assert rotation.run_assign_hosts(db, NOV_1) == {"rondas": 1, "rotated": 1, "stamped": 0}

        assert db.documents[f"rondas/{RONDA}"]["hosts"] == {
            "month": "2026-11",
            "anfitrion": "demo-102",
            "anfitrionName": "Jorge",
            "cola": "demo-103",
            "colaName": "Ana",
        }
        assert pairs(db) == [
            ("2026-11", "Jorge", "Ana"),
            ("2026-12", "Ana", "Facu"),
            ("2027-01", "Facu", "Mirta"),
        ]
        (entry,) = [v for k, v in db.documents.items() if k.startswith(f"acta/{RONDA}/")]
        assert entry["summary"] == "Este mes abre Jorge y cierra Ana. Así toca por turno."
        assert entry["decidedBy"] == "rule"
        run = db.documents[f"agent_runs/{RONDA}_2026-11_hosts"]
        assert (run["job"], run["model"], run["status"]) == ("assign_hosts", "", "done")

    def test_the_rest_of_the_month_changes_nothing(self):
        db = ronda()
        rotation.run_assign_hosts(db, NOV_1)

        assert rotation.run_assign_hosts(db, at(15, 12)) == {
            "rondas": 1,
            "rotated": 0,
            "stamped": 0,
        }

    def test_months_missed_are_caught_up(self):
        db = ronda(month="2026-09")

        rotation.run_assign_hosts(db, NOV_1)

        assert pairs(db)[0] == ("2026-11", "Ana", "Facu")

    def test_hosts_from_before_the_turns_get_the_month_stamped_and_keep_their_pair(self):
        db = ronda(month=None)

        assert rotation.run_assign_hosts(db, NOV_1) == {"rondas": 1, "rotated": 0, "stamped": 1}

        assert db.documents[f"rondas/{RONDA}"]["hosts"]["month"] == "2026-11"
        assert pairs(db)[0] == ("2026-11", "Mirta", "Jorge")
        assert not [k for k in db.documents if k.startswith("acta/")]

    def test_nothing_starts_the_turns_but_the_admin(self):
        db = ronda()
        db.documents[f"rondas/{RONDA}"]["hosts"] = {"anfitrion": HOST}
        db.documents["rondas/ended"] = {"status": "ended", "hosts": {"anfitrion": "x", "cola": "y"}}

        assert rotation.run_assign_hosts(db, NOV_1) == {"rondas": 0, "rotated": 0, "stamped": 0}
