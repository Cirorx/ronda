"""The admin's place, hour and hosts for each ronda (hosts.py), over the Firestore stand-in.
The ronda is the rain check's Thursday-afternoon ronda with four invented members."""

import pytest

import attendance
import hosts
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import HOST, RONDA, at, documents
from tests.test_rsvp import Sender

NOW = at(2, 12)


def bare() -> FakeFirestore:
    """The ronda the way approve_proposal leaves it: no place, no hour, no hosts."""
    db = FakeFirestore(documents())
    ronda = db.documents[f"rondas/{RONDA}"]
    del ronda["place"]
    ronda["slot"] = {"day": "thu", "time": "afternoon"}
    return db


def setup(db, **fields):
    data = {"rondaId": RONDA, "place": None, "hour": None, "anfitrion": "", "cola": "", **fields}
    return hosts.set_setup(db, data, NOW)


class TestSetups:
    def test_lists_each_ronda_with_its_members_and_what_is_still_unset(self):
        db = bare()
        db.documents["rondas/ended"] = {"status": "ended", "slot": {"day": "thu"}}

        (row,) = hosts.setups(db)

        assert row == {
            "rondaId": RONDA,
            "line": "Jueves a la tarde · mate en la rambla",
            "pretext": "mate",
            "barrio": "el-pinar-sur",
            "slot": {"day": "thu", "time": "afternoon"},
            "hour": None,
            "place": None,
            "hosts": {"anfitrion": "", "cola": ""},
            "members": [
                {"uid": "demo-103", "firstName": "Ana"},
                {"uid": "demo-104", "firstName": "Facu"},
                {"uid": "demo-102", "firstName": "Jorge"},
                {"uid": HOST, "firstName": "Mirta"},
            ],
            "roll": None,
        }

    def test_shows_what_is_set_and_the_latest_roll(self):
        db = FakeFirestore(documents(hosts={"anfitrion": HOST}))
        attendance.run_attendance_ask(db, at(5, 17), send=Sender())
        attendance.record(
            db, HOST, False, {"rondaId": RONDA, "week": "2026-W45", "uid": HOST, "came": True},
            at(5, 17),
        )  # fmt: skip
        db.documents[f"rondas/{RONDA}/rolls/2026-W44"] = {"date": "2026-10-29"}

        (row,) = hosts.setups(db)

        assert row["hour"] == "16:00"
        assert row["place"] == {"name": "frente al quiosco", "landmark": ""}
        assert row["hosts"] == {"anfitrion": HOST, "cola": ""}
        assert row["roll"] == {"week": "2026-W45", "date": "2026-11-05", "people": 4, "marked": 1}

    def test_a_landmark_that_isnt_text_reads_as_none(self):
        db = bare()
        db.documents[f"rondas/{RONDA}"]["place"] = {"name": "la plaza", "landmark": 3}

        assert hosts.setups(db)[0]["place"] == {"name": "la plaza", "landmark": ""}


class TestSetSetup:
    def test_sets_place_hour_and_hosts_with_their_first_names(self):
        db = bare()

        result = setup(
            db,
            place={"name": "  frente al   quiosco ", "landmark": "al lado de la parada"},
            hour="16:30",
            anfitrion="demo-102",
            cola="demo-103",
        )

        ronda = db.documents[f"rondas/{RONDA}"]
        assert ronda["place"] == {"name": "frente al quiosco", "landmark": "al lado de la parada"}
        assert ronda["slot"] == {"day": "thu", "time": "afternoon", "hour": "16:30"}
        assert ronda["hosts"] == {
            "anfitrion": "demo-102",
            "cola": "demo-103",
            "anfitrionName": "Jorge",
            "colaName": "Ana",
        }
        assert ronda["setupAt"] == NOW
        assert result["hosts"] == ronda["hosts"]

    def test_empty_values_take_each_one_away(self):
        db = FakeFirestore(documents(hosts={"anfitrion": HOST}))

        setup(db, place={"name": "la plaza"}, cola="demo-104")
        ronda = db.documents[f"rondas/{RONDA}"]
        assert ronda["place"] == {"name": "la plaza"}
        assert ronda["slot"] == {"day": "thu", "time": "afternoon"}
        assert ronda["hosts"] == {"cola": "demo-104", "colaName": "Facu"}

        setup(db)
        ronda = db.documents[f"rondas/{RONDA}"]
        assert "place" not in ronda
        assert "hosts" not in ronda

    @pytest.mark.parametrize(
        ("fields", "code"),
        [
            ({"place": "la plaza"}, "invalid-argument"),
            ({"place": {"name": " "}}, "invalid-argument"),
            ({"place": {"name": 3}}, "invalid-argument"),
            ({"place": {"name": "x" * 61}}, "invalid-argument"),
            ({"place": {"name": "en lo de Mirta"}}, "failed-precondition"),
            (
                {"place": {"name": "la plaza", "landmark": "Av. Central 1234"}},
                "failed-precondition",
            ),
            ({"hour": "21:00"}, "invalid-argument"),
            ({"hour": 16}, "invalid-argument"),
            ({"anfitrion": "demo-999"}, "invalid-argument"),
            ({"cola": 7}, "invalid-argument"),
            ({"anfitrion": HOST, "cola": HOST}, "invalid-argument"),
            ({"rondaId": "a/b"}, "invalid-argument"),
            ({"rondaId": "nope"}, "not-found"),
        ],
    )
    def test_refuses_what_isnt_a_public_place_an_hour_in_the_band_or_a_member(self, fields, code):
        db = bare()

        with pytest.raises(hosts.SetupError) as excinfo:
            setup(db, **fields)
        assert excinfo.value.code == code
        assert "setupAt" not in db.documents.get(f"rondas/{RONDA}", {})

    def test_a_host_who_left_cant_be_chosen(self):
        db = bare()
        db.documents[f"rondas/{RONDA}/members/demo-104"]["state"] = "left"

        with pytest.raises(hosts.SetupError):
            setup(db, anfitrion="demo-104")

    def test_a_body_that_isnt_an_object_has_no_ronda(self):
        with pytest.raises(hosts.SetupError) as excinfo:
            hosts.set_setup(bare(), None, NOW)
        assert excinfo.value.code == "invalid-argument"
