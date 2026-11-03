"""Publishing the seat catalogue (seat_catalog.py) over the Firestore stand-in."""

from datetime import UTC, datetime

import jobs
import seat_catalog
from ronda_solver.seats import catalogue, version
from tests.fake_firestore import FakeFirestore

NOW = datetime(2026, 11, 3, 1, tzinfo=UTC)


def test_publishes_every_seat_and_the_version():
    db = FakeFirestore()

    counts = seat_catalog.run_seat_catalog(db, NOW)

    assert counts == {"version": version(catalogue()), "published": 71 * 7}
    assert db.documents["seat_facts/palermo_mate"] == catalogue()["palermo_mate"]
    assert db.documents["config/seat_catalog"] == {
        "version": counts["version"],
        "seats": 497,
        "updatedAt": NOW,
    }


def test_writes_nothing_while_the_version_matches():
    db = FakeFirestore()
    seat_catalog.run_seat_catalog(db, NOW)
    db.documents["seat_facts/palermo_mate"] = {"edited": True}

    counts = seat_catalog.run_seat_catalog(db, NOW)

    assert counts["published"] == 0
    assert db.documents["seat_facts/palermo_mate"] == {"edited": True}


def test_publishes_again_when_the_version_differs_or_when_forced():
    db = FakeFirestore({"config/seat_catalog": {"version": "older"}})
    assert seat_catalog.run_seat_catalog(db, NOW)["published"] == 497

    db.documents["seat_facts/palermo_mate"] = {"edited": True}
    assert seat_catalog.run_seat_catalog(db, NOW, force=True)["published"] == 497
    assert db.documents["seat_facts/palermo_mate"] == catalogue()["palermo_mate"]


def test_leaves_a_seat_for_one_slot_as_it_is():
    one_slot = {"barrio": "solymar-sur", "pretext": "mate", "slot": "sat-afternoon"}
    db = FakeFirestore({"seat_facts/solymar-sur_mate_sat-afternoon": one_slot})

    seat_catalog.run_seat_catalog(db, NOW)

    assert db.documents["seat_facts/solymar-sur_mate_sat-afternoon"] == one_slot


def test_the_dispatcher_runs_it():
    assert "seat_catalog" in jobs.JOBS
    assert jobs.run("seat_catalog", FakeFirestore(), NOW, jobs.context())["published"] == 497
