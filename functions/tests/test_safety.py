"""safety.py ([Separarlos], [Juntarlos de nuevo] and the reads every seating path makes) and
removals.py ([Sacar de Ronda], its notice, [Dejar entrar de nuevo]) over the Firestore stand-in
and an invented world."""

import pytest

import jobs
import removals
import reports
import safety
from tests.fake_firestore import FakeFirestore
from tests.safety_fakes import NIGHT, NOW, world
from tests.test_rsvp import Sender


def report(db, reporter="ana", about="beto"):
    return reports.file(db, reporter, {"text": "Me molestó", "aboutUid": about}, NOW)["reportId"]


class TestReads:
    def test_pairs_read_both_ways_and_skip_a_broken_document(self):
        db = FakeFirestore(world())
        db.documents["avoid/ana_beto"] = {"uidA": "ana", "uidB": "beto"}
        db.documents["avoid/cora_fede"] = {"uidA": "cora", "uidB": "fede"}
        db.documents["avoid/broken"] = {"uidA": "ana"}

        assert safety.apart(db) == {
            "ana": {"beto"},
            "beto": {"ana"},
            "cora": {"fede"},
            "fede": {"cora"},
        }
        assert safety.apart_from(db, ["beto", "cora"]) == {"ana", "fede"}
        assert safety.apart_from(db, []) == set()

    def test_the_pair_id_is_the_same_whoever_reported_whom(self):
        assert safety.pair_id("beto", "ana") == safety.pair_id("ana", "beto") == "ana_beto"

    def test_seated_in_counts_rondas_that_still_meet_where_they_take_a_seat(self):
        db = FakeFirestore(world())
        db.documents["rondas/r2"]["status"] = "ended"
        db.documents["users/ana/rondas/gone"] = {}

        assert list(safety.seated_in(db, "ana")) == ["r1"]
        assert safety.seated_in(db, "dani") == {}


class TestSeparate:
    def test_writes_the_pair_with_names_and_says_they_still_sit_together(self):
        db = FakeFirestore(world())
        report_id = report(db, "beto", "ana")

        result = safety.separate(db, {"reportId": report_id}, NOW)

        together = {"rondaId": "r1", "line": "Sábado a la tarde · mate en la rambla"}
        assert result == {"pairId": "ana_beto", "together": together}
        assert db.documents["avoid/ana_beto"] == {
            "uidA": "ana",
            "uidB": "beto",
            "nameA": "Ana",
            "nameB": "Beto",
            "reportId": report_id,
            "together": together,
            "at": NOW,
        }
        assert db.documents["rondas/r1/members/ana"]["state"] == "active"

    def test_a_pair_in_no_ronda_together_is_just_kept_apart(self):
        db = FakeFirestore(world())

        result = safety.separate(db, {"reportId": report(db, "fede", "ana")}, NOW)

        assert result == {
            "pairId": "ana_fede",
            "together": {"rondaId": "r2", "line": "Martes a la noche · truco"},
        }
        result = safety.separate(db, {"reportId": report(db, "ana", "dani")}, NOW)
        assert result == {"pairId": "ana_dani", "together": None}

    def test_juntarlos_de_nuevo_deletes_the_pair(self):
        db = FakeFirestore(world())
        safety.separate(db, {"reportId": report(db)}, NOW)

        assert safety.join_again(db, {"pairId": "ana_beto"}) == {"pairId": "ana_beto"}
        assert "avoid/ana_beto" not in db.documents
        with pytest.raises(safety.SafetyError) as excinfo:
            safety.join_again(db, {"pairId": "ana_beto"})
        assert excinfo.value.code == "not-found"

    @pytest.mark.parametrize("data", [None, {}, {"pairId": ""}, {"pairId": "a/b"}])
    def test_juntarlos_needs_a_pair_id(self, data):
        with pytest.raises(safety.SafetyError) as excinfo:
            safety.join_again(FakeFirestore(world()), data)
        assert excinfo.value.code == "invalid-argument"

    def test_refuses_a_report_about_someone_from_outside_or_without_a_reporter(self):
        db = FakeFirestore(world())
        outside = reports.file(db, "ana", {"text": "En la plaza", "aboutUid": ""}, NOW)["reportId"]
        db.documents["reports/odd"] = {"aboutUid": "beto", "reporterUid": ""}

        for report_id in (outside, "odd"):
            with pytest.raises(safety.SafetyError) as excinfo:
                safety.separate(db, {"reportId": report_id}, NOW)
            assert excinfo.value.code == "failed-precondition"

    @pytest.mark.parametrize(
        ("data", "code"),
        [
            (None, "invalid-argument"),
            ({"reportId": "a/b"}, "invalid-argument"),
            ({"reportId": "x"}, "not-found"),
        ],
    )
    def test_refuses_a_report_it_cannot_find(self, data, code):
        with pytest.raises(safety.SafetyError) as excinfo:
            safety.separate(FakeFirestore(world()), data, NOW)
        assert excinfo.value.code == code


class TestRemove:
    def test_takes_them_out_of_every_ronda_and_sends_one_neutral_notice(self):
        db = FakeFirestore(world())
        db.documents["users/beto/offers/o1"] = {"status": "pending"}
        db.documents["users/beto/offers/o0"] = {"status": "taken"}
        report_id = report(db)
        sender = Sender()

        result = removals.remove(db, {"reportId": report_id}, NOW, send=sender, app_url="https://x")

        assert result == {"uid": "beto", "rondaIds": ["r1"], "notice": "sent"}
        assert db.documents["rondas/r1/members/beto"] == {
            "brings": ["pan"],
            "state": "left",
            "joinedAt": db.documents["rondas/r1/members/beto"]["joinedAt"],
            "leftAt": NOW,
        }
        assert "users/beto/rondas/r1" not in db.documents
        assert db.documents["rondas/r1"]["size"] == 2
        view = db.documents["rondas/r1/views/week"]
        assert [g["uid"] for g in view["going"]] == ["ana"]
        assert db.documents["users/beto/offers/o1"] == {"status": "withdrawn", "closedAt": NOW}
        assert db.documents["users/beto/offers/o0"] == {"status": "taken"}
        assert db.documents["removed/beto"] == {
            "firstName": "Beto",
            "reportId": report_id,
            "at": NOW,
            "rondaIds": ["r1"],
            "notice": "sent",
            "noticeAt": NOW,
        }
        [message] = sender.messages
        assert message["token"] == "tok-beto"
        body = message["data"]["body"]
        assert body.endswith("Ya no estás en esta ronda.") and "Soy un programa" in body
        assert "Ana" not in body and "molest" not in body
        assert message["data"]["type"] == "notice"

    def test_the_notice_is_in_the_admins_trace_and_never_in_the_acta(self):
        db = FakeFirestore(world())

        removals.remove(db, {"reportId": report(db)}, NOW, send=Sender())

        assert db.documents["agent_runs/r1_2026-W45_notice_beto"]["job"] == "removal_notices"
        assert not [p for p in db.documents if p.startswith("acta/")]

    def test_someone_in_no_ronda_is_kept_out_with_nothing_to_tell(self):
        db = FakeFirestore(world())
        sender = Sender()

        result = removals.remove(db, {"reportId": report(db, "ana", "dani")}, NOW, send=sender)

        assert result == {"uid": "dani", "rondaIds": [], "notice": "none"}
        assert db.documents["removed/dani"]["notice"] == "none"
        assert "users/dani/rondas/r1" not in db.documents
        assert sender.messages == []

    def test_at_night_the_notice_waits_for_the_hourly_job(self):
        db = FakeFirestore(world())
        sender = Sender()

        result = removals.remove(db, {"reportId": report(db)}, NIGHT, send=sender)

        assert result["notice"] == "pending"
        assert db.documents["rondas/r1/members/beto"]["state"] == "left"
        assert sender.messages == []
        assert not [p for p in db.documents if p.startswith("agent_runs/")]
        assert removals.run_removal_notices(db, NIGHT, send=sender) == {"sent": 0, "waiting": 1}

        context = jobs.Context(send=sender)
        assert jobs.run("removal_notices", db, NOW, context) == {"sent": 1, "waiting": 0}
        assert db.documents["removed/beto"]["notice"] == "sent"
        assert len(sender.messages) == 1
        assert jobs.run("removal_notices", db, NOW, context) == {"sent": 0, "waiting": 0}

    def test_a_person_with_no_phone_is_unreachable(self):
        db = FakeFirestore(world())
        del db.documents["users/beto/tokens/tok-beto"]

        assert (
            removals.remove(db, {"reportId": report(db)}, NOW, send=Sender())["notice"]
            == "unreachable"
        )

    def test_refuses_someone_already_out_or_from_outside(self):
        db = FakeFirestore(world())
        report_id = report(db)
        removals.remove(db, {"reportId": report_id}, NOW, send=Sender())
        outside = reports.file(db, "ana", {"text": "En la plaza", "aboutUid": ""}, NOW)["reportId"]

        with pytest.raises(safety.SafetyError) as excinfo:
            removals.remove(db, {"reportId": report_id}, NOW, send=Sender())
        assert excinfo.value.code == "already-exists"
        with pytest.raises(safety.SafetyError) as excinfo:
            removals.remove(db, {"reportId": outside}, NOW, send=Sender())
        assert excinfo.value.code == "failed-precondition"


class TestLetBackIn:
    def test_deletes_the_record_and_seats_nobody(self):
        db = FakeFirestore(world())
        removals.remove(db, {"reportId": report(db)}, NOW, send=Sender())

        assert removals.let_back_in(db, {"uid": "beto"}) == {"uid": "beto"}

        assert "removed/beto" not in db.documents
        assert db.documents["rondas/r1/members/beto"]["state"] == "left"

    @pytest.mark.parametrize(
        ("data", "code"),
        [
            (None, "invalid-argument"),
            ({"uid": ""}, "invalid-argument"),
            ({"uid": "a/b"}, "invalid-argument"),
            ({"uid": "gabi"}, "not-found"),
        ],
    )
    def test_refuses_what_it_cannot_undo(self, data, code):
        with pytest.raises(safety.SafetyError) as excinfo:
            removals.let_back_in(FakeFirestore(world()), data)
        assert excinfo.value.code == code
