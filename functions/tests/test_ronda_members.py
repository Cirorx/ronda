"""ronda_members.py ("Sumar a esta ronda") on invented people, over the Firestore stand-in. Every
uid and name is invented; uids that don't start with `demo-` play real sign-ups."""

from datetime import UTC, datetime

import pytest

import ronda_members
from tests.fake_firestore import FakeFirestore
from tests.test_demo_users import on_the_real_project

NOW = datetime(2026, 10, 30, 15, 0, tzinfo=UTC)  # Friday; r1 meets Saturday 31/10 (2026-W44)
EARLIER = datetime(2026, 10, 27, 15, 0, tzinfo=UTC)
SEAT = "el-pinar-sur_mate_sat-afternoon"


def user(name, barrio="el-pinar-norte", slots=("sat-afternoon",), pretexts=("mate",), **more):
    return {
        "firstName": name,
        "ageBand": "30-39",
        "barrio": barrio,
        "slots": list(slots),
        "pretexts": list(pretexts),
        "brings": ["pan"],
        **more,
    }


def member(state="active", **more):
    return {"brings": ["pan"], "state": state, "joinedAt": EARLIER, **more}


def group(seat, uids):
    return {
        "id": seat,
        "members": [
            {"uid": uid, "firstName": uid.title(), "ageBand": "30-39", "distanceBlocks": 0}
            for uid in uids
        ],
    }


def world(**extra) -> dict[str, dict]:
    documents = {
        "rondas/r1": {
            "seatId": SEAT,
            "pretext": "mate",
            "barrio": "el-pinar-sur",
            "slot": {"day": "sat", "time": "afternoon"},
            "size": 3,
            "status": "forming",
        },
        "rondas/r2": {
            "seatId": "el-pinar-norte_truco_tue-evening",
            "pretext": "truco",
            "barrio": "el-pinar-norte",
            "slot": {"day": "tue", "time": "evening"},
            "size": 4,
            "status": "forming",
        },
        "rondas/r1/weeks/2026-W44": {"date": "2026-10-31", "rsvp": {"ana": "yes"}},
        "users/ana": user("Ana", "el-pinar-sur", plusOneUid="eva"),
        "users/beto": user("Beto", "el-pinar-sur"),
        "users/cora": user("Cora", "el-pinar-sur"),
        "users/dani": user("Dani", "el-pinar-sur"),
        "users/eva": user("Eva", plusOneUid="ana"),
        "users/eva/private/eligible": {"seatIds": [SEAT]},
        "users/fede": user("Fede", "lagomar-sur", slots=["tue-evening"], pretexts=["truco"]),
        "users/gabi": user("Gabi", "el-pinar-norte", slots=["tue-evening", "sat-afternoon"]),
        "users/gabi/private/eligible": {"seatIds": [SEAT]},
        "users/gabi/rondas/r2": {"joinedAt": EARLIER},
        "users/dani/rondas/r1": {"joinedAt": EARLIER},
        "users/demo-007": user("Vecina"),
        "users/hugo": {"terms": {}},
        "users/ines": user("Inés", "pocitos"),
        "proposals/p1": {
            "status": "approved",
            "rondaIds": ["r1", "r2"],
            "groups": [group(SEAT, ["ana", "beto", "cora"]), group("x", ["gabi"])],
            "unseated": ["eva"],
            "unseatedPeople": [{"uid": "eva", "firstName": "Eva"}],
        },
        "proposals/p0": {"status": "pending", "rondaIds": ["r1"], "groups": []},
    }
    for uid in ("ana", "beto", "cora"):
        documents[f"rondas/r1/members/{uid}"] = member()
        documents[f"users/{uid}/rondas/r1"] = {"joinedAt": EARLIER}
    documents["rondas/r1/members/dani"] = member("left", leftAt=EARLIER)
    documents["rondas/r2/members/gabi"] = member()
    return documents | extra


class TestWarnings:
    def test_a_match_has_none(self):
        db = FakeFirestore(world())
        ronda = db.documents["rondas/r1"]

        assert ronda_members.warnings(ronda, db.documents["users/eva"], [SEAT]) == []

    def test_names_the_slot_the_pretext_a_far_barrio_and_a_seat_the_phone_left_out(self):
        db = FakeFirestore(world())
        ronda = db.documents["rondas/r1"]

        found = ronda_members.warnings(ronda, db.documents["users/fede"], None)

        assert found == ["slot", "pretext", "barrio", "seat"]

    def test_an_unknown_barrio_is_far(self):
        assert ronda_members.blocks("pocitos", "el-pinar-sur") is None
        ronda = {"barrio": "el-pinar-sur", "pretext": "mate", "slot": {"day": "sat"}}
        assert "barrio" in ronda_members.warnings(ronda, {"barrio": "pocitos"}, [])

    def test_the_seat_id_falls_back_to_the_rondas_key(self):
        ronda = {"barrio": "b", "pretext": "mate", "slot": {"day": "sat", "time": "afternoon"}}

        assert ronda_members.seat_id(ronda) == "b_mate_sat-afternoon"


class TestCandidates:
    def test_lists_sign_ups_outside_the_ronda_those_in_no_ronda_first(self):
        listed = ronda_members.candidates(FakeFirestore(world()), "r1")

        assert listed["line"] == "Sábado a la tarde · mate en la rambla"
        assert (listed["members"], listed["taken"], listed["cap"]) == (
            ["Ana", "Beto", "Cora"],
            3,
            6,
        )
        assert [p["uid"] for p in listed["people"]] == ["dani", "eva", "fede", "demo-007", "gabi"]
        eva = listed["people"][1]
        assert eva == {
            "uid": "eva",
            "firstName": "Eva",
            "barrio": "el-pinar-norte",
            "slots": ["sat-afternoon"],
            "pretexts": ["mate"],
            "ageBand": "30-39",
            "blocks": 9,
            "warnings": [],
            "rondaId": None,
            "rondaLine": None,
        }
        gabi = listed["people"][-1]
        assert (gabi["rondaId"], gabi["rondaLine"]) == ("r2", "Martes a la noche · truco")

    def test_on_the_real_project_leaves_the_invented_sign_ups_out(self, monkeypatch):
        on_the_real_project(monkeypatch)

        listed = ronda_members.candidates(FakeFirestore(world()), "r1")

        assert "demo-007" not in [p["uid"] for p in listed["people"]]

    def test_refuses_an_unknown_ronda_or_one_that_no_longer_meets(self):
        db = FakeFirestore(world())
        db.documents["rondas/r1"]["status"] = "ended"

        with pytest.raises(ronda_members.MemberError) as excinfo:
            ronda_members.candidates(db, "r1")
        assert excinfo.value.code == "failed-precondition"
        with pytest.raises(ronda_members.MemberError) as excinfo:
            ronda_members.candidates(db, "nope")
        assert excinfo.value.code == "not-found"


class TestAdd:
    def test_writes_the_member_and_their_link_in_one_go_as_sin_contestar(self):
        db = FakeFirestore(world())

        result = ronda_members.add(db, "r1", "eva", NOW)

        assert result == {"rondaId": "r1", "uid": "eva", "warnings": [], "movedFrom": None}
        assert db.documents["rondas/r1/members/eva"] == {
            "brings": ["pan"],
            "state": "active",
            "joinedAt": NOW,
        }
        assert db.documents["users/eva/rondas/r1"] == {"joinedAt": NOW}
        assert db.documents["rondas/r1"]["size"] == 4
        view = db.documents["rondas/r1/views/week"]
        assert (view["week"], [g["uid"] for g in view["going"]]) == ("2026-W44", ["ana"])
        assert (view["noCount"], view["unansweredCount"]) == (0, 3)
        assert "eva" not in db.documents["rondas/r1/weeks/2026-W44"]["rsvp"]

    def test_puts_them_in_the_approved_proposals_group_and_out_of_the_left_out(self):
        db = FakeFirestore(world())

        ronda_members.add(db, "r1", "eva", NOW)

        proposal = db.documents["proposals/p1"]
        assert (proposal["unseated"], proposal["unseatedPeople"]) == ([], [])
        members = {m["uid"]: m for m in proposal["groups"][0]["members"]}
        assert members["eva"] == {
            "uid": "eva",
            "firstName": "Eva",
            "ageBand": "30-39",
            "distanceBlocks": 9,
            "plusOneInGroup": True,
        }
        assert members["ana"]["plusOneInGroup"] is True
        assert "plusOneInGroup" not in members["beto"]
        assert db.documents["proposals/p0"]["groups"] == []

    def test_re_adds_someone_who_left_this_ronda(self):
        db = FakeFirestore(world())

        ronda_members.add(db, "r1", "dani", NOW)

        assert db.documents["rondas/r1/members/dani"]["state"] == "active"
        assert "leftAt" not in db.documents["rondas/r1/members/dani"]

    def test_returns_what_does_not_match(self):
        db = FakeFirestore(world())

        result = ronda_members.add(db, "r1", "fede", NOW)

        assert result["warnings"] == ["slot", "pretext", "barrio", "seat"]

    def test_deletes_a_link_to_a_ronda_they_already_left(self):
        db = FakeFirestore(world())
        db.documents["users/eva/rondas/r0"] = {"joinedAt": EARLIER}
        db.documents["rondas/r0"] = {"status": "active", "slot": {"day": "mon"}}
        db.documents["rondas/r0/members/eva"] = member("left")

        assert ronda_members.add(db, "r1", "eva", NOW)["movedFrom"] is None

        assert "users/eva/rondas/r0" not in db.documents
        assert db.documents["rondas/r0/members/eva"]["state"] == "left"

    def test_moves_someone_from_another_ronda_only_when_asked(self):
        db = FakeFirestore(world())

        with pytest.raises(ronda_members.MemberError) as excinfo:
            ronda_members.add(db, "r1", "gabi", NOW)
        assert excinfo.value.code == "failed-precondition"
        assert "rondas/r1/members/gabi" not in db.documents

        result = ronda_members.add(db, "r1", "gabi", NOW, move=True)

        assert result["movedFrom"] == "r2"
        assert db.documents["rondas/r2/members/gabi"] == member("left", leftAt=NOW)
        assert "users/gabi/rondas/r2" not in db.documents
        assert db.documents["users/gabi/rondas/r1"] == {"joinedAt": NOW}
        assert db.documents["rondas/r2"]["size"] == 0
        assert db.documents["rondas/r2/views/week"]["unansweredCount"] == 0
        groups = db.documents["proposals/p1"]["groups"]
        assert [m["uid"] for m in groups[1]["members"]] == []
        assert "gabi" in [m["uid"] for m in groups[0]["members"]]

    def test_refuses_a_full_ronda(self):
        db = FakeFirestore(world())
        for uid in ("x1", "x2", "x3"):
            db.documents[f"rondas/r1/members/{uid}"] = member("paused")

        with pytest.raises(ronda_members.MemberError) as excinfo:
            ronda_members.add(db, "r1", "eva", NOW)

        assert excinfo.value.code == "resource-exhausted"
        assert "rondas/r1/members/eva" not in db.documents

    def test_refuses_someone_already_in_it(self):
        with pytest.raises(ronda_members.MemberError) as excinfo:
            ronda_members.add(FakeFirestore(world()), "r1", "ana", NOW)

        assert excinfo.value.code == "already-exists"

    @pytest.mark.parametrize("uid", ["hugo", "ines", "nobody"])
    def test_refuses_anyone_without_a_profile_in_a_known_barrio(self, uid):
        with pytest.raises(ronda_members.MemberError) as excinfo:
            ronda_members.add(FakeFirestore(world()), "r1", uid, NOW)

        assert excinfo.value.code == "not-found"

    def test_on_the_real_project_never_adds_an_invented_sign_up(self, monkeypatch):
        on_the_real_project(monkeypatch)
        db = FakeFirestore(world())

        with pytest.raises(ronda_members.MemberError) as excinfo:
            ronda_members.add(db, "r1", "demo-007", NOW)

        assert excinfo.value.code == "failed-precondition"
        assert "rondas/r1/members/demo-007" not in db.documents

    def test_an_invented_sign_up_joins_where_they_count(self):
        db = FakeFirestore(world())

        ronda_members.add(db, "r1", "demo-007", NOW)

        assert db.documents["rondas/r1/members/demo-007"]["state"] == "active"

    def test_a_ronda_no_proposal_made_changes_no_proposal(self):
        db = FakeFirestore(world())
        db.documents["proposals/p1"]["rondaIds"] = ["other", "r2"]
        before = dict(db.documents["proposals/p1"])

        ronda_members.add(db, "r1", "eva", NOW)

        assert db.documents["proposals/p1"] == before


class TestRegroup:
    def test_a_proposal_with_fewer_ronda_ids_than_groups_keeps_the_rest(self):
        proposal = {"rondaIds": ["r1"], "groups": [group("a", ["ana"]), group("b", ["eva"])]}
        entry = {"uid": "eva", "firstName": "Eva", "ageBand": "30-39", "distanceBlocks": 0}

        fields = ronda_members.regroup(proposal, "r1", "eva", entry, {"eva": "zoe"})

        assert [[m["uid"] for m in g["members"]] for g in fields["groups"]] == [["ana", "eva"], []]
        assert "plusOneInGroup" not in fields["groups"][0]["members"][1]
        assert fields["unseatedPeople"] == []
