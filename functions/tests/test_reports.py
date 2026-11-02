"""reports.py (Contar algo que pasó) over the Firestore stand-in and an invented world."""

from datetime import timedelta

import pytest

import reports
from tests.fake_firestore import FakeFirestore
from tests.safety_fakes import NOW, world


def report_of(db, report_id):
    return db.documents[f"reports/{report_id}"]


def filed(db, uid="ana", **data):
    return reports.file(db, uid, {"text": "Me insistió", "aboutUid": "beto", **data}, NOW)


class TestPeople:
    def test_lists_the_other_members_of_every_ronda_once_by_first_name(self):
        found = reports.people(FakeFirestore(world()), "ana")

        assert found == {
            "people": [
                {"uid": "beto", "firstName": "Beto", "rondaId": "r1"},
                {"uid": "cora", "firstName": "Cora", "rondaId": "r1"},
                {"uid": "dani", "firstName": "Dani", "rondaId": "r1"},
                {"uid": "fede", "firstName": "Fede", "rondaId": "r2"},
            ]
        }

    def test_someone_in_no_ronda_has_nobody_to_name(self):
        assert reports.people(FakeFirestore(world()), "gabi") == {"people": []}

    def test_leaves_out_a_member_without_a_first_name(self):
        db = FakeFirestore(world())
        db.documents["rondas/r1/members/hugo"] = {"state": "active"}

        assert "hugo" not in [p["uid"] for p in reports.people(db, "beto")["people"]]


class TestFile:
    def test_saves_the_report_for_the_admin_and_a_receipt_for_the_reporter(self):
        db = FakeFirestore(world())

        report_id = filed(db, tags=["bothered", "askedForMoney"])["reportId"]

        assert report_of(db, report_id) == {
            "reporterUid": "ana",
            "reporterName": "Ana",
            "aboutUid": "beto",
            "aboutName": "Beto",
            "rondaId": "r1",
            "rondaLine": "Sábado a la tarde · mate en la rambla",
            "tags": ["askedForMoney", "bothered"],
            "text": "Me insistió",
            "additions": [],
            "status": "open",
            "withdrawnAt": None,
            "unread": True,
            "createdAt": NOW,
            "updatedAt": NOW,
        }
        assert db.documents[f"users/ana/reports/{report_id}"] == {
            "status": "open",
            "createdAt": NOW,
        }

    def test_nothing_reaches_the_person_it_is_about(self):
        db = FakeFirestore(world())
        before = set(db.documents)

        filed(db)

        assert not [p for p in set(db.documents) - before if "beto" in p]

    def test_someone_from_outside_names_nobody_and_takes_the_reporters_ronda(self):
        db = FakeFirestore(world())

        report_id = filed(db, uid="fede", aboutUid="", text="  Un señor en la plaza  ")["reportId"]

        report = report_of(db, report_id)
        assert (report["aboutUid"], report["aboutName"], report["rondaId"]) == ("", "", "r2")
        assert report["text"] == "Un señor en la plaza"

    def test_without_a_ronda_it_names_none(self):
        db = FakeFirestore(world())

        report_id = reports.file(db, "gabi", {"tags": ["other"]}, NOW)["reportId"]

        assert (report_of(db, report_id)["rondaId"], report_of(db, report_id)["text"]) == ("", "")

    def test_a_ronda_that_is_gone_keeps_its_id_without_a_line(self):
        db = FakeFirestore(world())
        del db.documents["rondas/r2"]

        report_id = filed(db, uid="fede", aboutUid="")["reportId"]

        assert (report_of(db, report_id)["rondaId"], report_of(db, report_id)["rondaLine"]) == (
            "r2",
            "",
        )

    @pytest.mark.parametrize(
        "data",
        [
            None,
            {},
            {"text": "   "},
            {"text": 3},
            {"text": "x" * (reports.TEXT_LIMIT + 1)},
            {"text": "hola", "tags": "bothered"},
            {"text": "hola", "tags": ["insulted"]},
            {"text": "hola", "aboutUid": 7},
            {"text": "hola", "aboutUid": "gabi"},
            {"text": "hola", "aboutUid": "ana"},
        ],
    )
    def test_refuses_what_it_cannot_save(self, data):
        db = FakeFirestore(world())

        with pytest.raises(reports.ReportError) as excinfo:
            reports.file(db, "ana", data, NOW)

        assert excinfo.value.code == "invalid-argument"
        assert not [p for p in db.documents if p.startswith("reports/")]

    def test_takes_five_a_day(self):
        db = FakeFirestore(world())
        db.documents["users/ana/reports/old"] = {"createdAt": NOW - timedelta(days=2)}
        for _ in range(reports.DAILY_LIMIT):
            filed(db)

        with pytest.raises(reports.ReportError) as excinfo:
            filed(db)

        assert excinfo.value.code == "resource-exhausted"


class TestAddAndWithdraw:
    def test_adding_appends_and_brings_an_archived_report_back_unread(self):
        db = FakeFirestore(world())
        report_id = filed(db)["reportId"]
        reports.review(db, {"reportId": report_id, "action": "archive"}, NOW)
        later = NOW + timedelta(hours=1)

        reports.add(db, "ana", {"reportId": report_id, "text": " Y otra vez el jueves "}, later)

        report = report_of(db, report_id)
        assert report["additions"] == [{"text": "Y otra vez el jueves", "at": later}]
        assert (report["status"], report["unread"], report["updatedAt"]) == ("open", True, later)

    def test_withdrawing_keeps_it_in_the_queue_marked_and_unread(self):
        db = FakeFirestore(world())
        report_id = filed(db)["reportId"]
        reports.review(db, {"reportId": report_id, "action": "read"}, NOW)

        reports.withdraw(db, "ana", {"reportId": report_id}, NOW)

        report = report_of(db, report_id)
        assert (report["status"], report["withdrawnAt"], report["unread"]) == ("open", NOW, True)
        assert db.documents[f"users/ana/reports/{report_id}"]["status"] == "withdrawn"

    def test_a_withdrawn_report_takes_nothing_more(self):
        db = FakeFirestore(world())
        report_id = filed(db)["reportId"]
        reports.withdraw(db, "ana", {"reportId": report_id}, NOW)

        for step in (
            lambda: reports.add(db, "ana", {"reportId": report_id, "text": "más"}, NOW),
            lambda: reports.withdraw(db, "ana", {"reportId": report_id}, NOW),
        ):
            with pytest.raises(reports.ReportError) as excinfo:
                step()
            assert excinfo.value.code == "failed-precondition"

    @pytest.mark.parametrize("uid", ["beto", "gabi"])
    def test_only_the_reporter_changes_it(self, uid):
        db = FakeFirestore(world())
        report_id = filed(db)["reportId"]

        with pytest.raises(reports.ReportError) as excinfo:
            reports.withdraw(db, uid, {"reportId": report_id}, NOW)

        assert excinfo.value.code == "not-found"

    @pytest.mark.parametrize("data", [None, {}, {"reportId": ""}, {"reportId": "a/b"}])
    def test_needs_a_report_id(self, data):
        with pytest.raises(reports.ReportError) as excinfo:
            reports.withdraw(FakeFirestore(world()), "ana", data, NOW)

        assert excinfo.value.code == "invalid-argument"

    def test_an_addition_needs_words_and_a_report_takes_twenty(self):
        db = FakeFirestore(world())
        report_id = filed(db)["reportId"]
        with pytest.raises(reports.ReportError) as excinfo:
            reports.add(db, "ana", {"reportId": report_id, "text": ""}, NOW)
        assert excinfo.value.code == "invalid-argument"

        for n in range(reports.ADDITIONS_LIMIT):
            reports.add(db, "ana", {"reportId": report_id, "text": f"línea {n}"}, NOW)
        with pytest.raises(reports.ReportError) as excinfo:
            reports.add(db, "ana", {"reportId": report_id, "text": "una más"}, NOW)
        assert excinfo.value.code == "resource-exhausted"


class TestReview:
    def test_reading_archiving_and_reopening(self):
        db = FakeFirestore(world())
        report_id = filed(db)["reportId"]

        assert reports.review(db, {"reportId": report_id, "action": "read"}, NOW) == {
            "reportId": report_id,
            "status": "open",
        }
        assert report_of(db, report_id)["unread"] is False
        reports.add(db, "ana", {"reportId": report_id, "text": "más"}, NOW)

        reports.review(db, {"reportId": report_id, "action": "archive"}, NOW)
        assert (report_of(db, report_id)["status"], report_of(db, report_id)["unread"]) == (
            "archived",
            False,
        )
        reports.review(db, {"reportId": report_id, "action": "reopen"}, NOW)
        assert report_of(db, report_id)["status"] == "open"

    def test_the_receipt_never_says_what_the_admin_did(self):
        db = FakeFirestore(world())
        report_id = filed(db)["reportId"]

        reports.review(db, {"reportId": report_id, "action": "archive"}, NOW)

        assert db.documents[f"users/ana/reports/{report_id}"]["status"] == "open"

    def test_refuses_an_unknown_action_or_report(self):
        db = FakeFirestore(world())
        report_id = filed(db)["reportId"]
        with pytest.raises(reports.ReportError) as excinfo:
            reports.review(db, {"reportId": report_id, "action": "delete"}, NOW)
        assert excinfo.value.code == "invalid-argument"
        with pytest.raises(reports.ReportError) as excinfo:
            reports.review(db, {"reportId": "nope", "action": "read"}, NOW)
        assert excinfo.value.code == "not-found"
