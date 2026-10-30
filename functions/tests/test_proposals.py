"""proposals.py on invented sign-ups, over the in-memory Firestore stand-in."""

import json
from datetime import UTC, datetime
from pathlib import Path

import pytest

import proposals
from tests.fake_firestore import FakeFirestore
from tests.test_demo_users import on_a_demo_project, on_the_real_project, under_the_emulator

FIXTURE = Path(__file__).resolve().parents[2] / "solver" / "fixtures" / "invented_demo_30.json"
NOW = datetime(2026, 10, 27, 15, 0, tzinfo=UTC)
ADMIN = "demo-admin"


def invented_sign_ups() -> dict[str, dict]:
    """The solver's 30-person fixture as Firestore documents, with invented first names."""
    problem = json.loads(FIXTURE.read_text())
    documents: dict[str, dict] = {}
    for index, person in enumerate(problem["people"]):
        uid = person["uid"]
        documents[f"users/{uid}"] = {
            "firstName": f"Vecina {index}",
            "ageBand": person["ageBand"],
            "barrio": person["barrio"],
            "slots": person["slots"],
            "pretexts": person["pretexts"],
            "brings": ["pan"],
            **({"plusOneUid": person["plusOneUid"]} if "plusOneUid" in person else {}),
        }
        documents[f"users/{uid}/private/eligible"] = {"seatIds": person["eligibleSeatIds"]}
    for uid_a, uid_b in problem["avoidPairs"]:
        documents[f"avoid/{uid_a}_{uid_b}"] = {"uidA": uid_a, "uidB": uid_b}
    return documents


def proposal_path(db: FakeFirestore) -> str:
    [path] = [p for p in db.documents if p.startswith("proposals/")]
    return path


class TestSolverInput:
    def test_takes_only_people_with_a_profile_a_known_barrio_and_eligible_ids(self):
        users = {
            "a": {"firstName": "Ana", "ageBand": "60-69", "barrio": "solymar-sur"},
            "terms-only": {"terms": {}},
            "elsewhere": {"firstName": "Bea", "ageBand": "30-39", "barrio": "pocitos"},
            "no-ids": {"firstName": "Cris", "ageBand": "30-39", "barrio": "solymar-sur"},
        }
        eligible = {"a": ["solymar-sur_mate_sat-afternoon"], "elsewhere": ["x"], "terms-only": []}

        data = proposals.solver_input(users, eligible, [])

        assert [p["uid"] for p in data["people"]] == ["a"]
        assert data["people"][0] == {
            "uid": "a",
            "ageBand": "60-69",
            "barrio": "solymar-sur",
            "pretexts": [],
            "slots": [],
            "eligibleSeatIds": ["solymar-sur_mate_sat-afternoon"],
        }

    def test_carries_the_plus_one_and_the_avoid_pairs(self):
        users = {"a": {"firstName": "Ana", "ageBand": "60-69", "barrio": "lagomar-sur",
                       "plusOneUid": "b"}}  # fmt: skip

        data = proposals.solver_input(users, {"a": []}, [{"uidA": "a", "uidB": "c"}])

        assert data["people"][0]["plusOneUid"] == "b"
        assert data["avoidPairs"] == [["a", "c"]]

    def test_never_sends_a_name_or_anything_beyond_the_contract(self):
        users = {"a": {"firstName": "Ana", "ageBand": "60-69", "barrio": "lagomar-sur",
                       "brings": ["pan"], "terms": {}}}  # fmt: skip

        [person] = proposals.solver_input(users, {"a": []}, [])["people"]

        assert set(person) == {"uid", "ageBand", "barrio", "pretexts", "slots", "eligibleSeatIds"}


class TestPropose:
    def test_writes_one_pending_proposal_with_first_names_and_the_reason(self):
        db = FakeFirestore(invented_sign_ups())

        summary = proposals.propose(db, ADMIN, NOW)

        proposal = db.documents[proposal_path(db)]
        assert summary["proposalId"] == proposal_path(db).split("/")[1]
        assert summary["groups"] == len(proposal["groups"]) > 0
        assert proposal["status"] == "pending"
        assert proposal["createdBy"] == ADMIN
        assert proposal["createdAt"] == NOW
        member = proposal["groups"][0]["members"][0]
        assert member["firstName"].startswith("Vecina ")
        assert {"uid", "ageBand", "distanceBlocks"} <= set(member)
        assert proposal["rejectedAlternative"]["reason"].startswith("Alternativa B rechazada: ")

    def test_leaves_out_a_member_whose_phone_sent_no_seat_ids_yet(self):
        sign_ups = invented_sign_ups()
        del sign_ups["users/demo-001/private/eligible"]
        db = FakeFirestore(sign_ups)

        proposals.propose(db, ADMIN, NOW)

        proposal = db.documents[proposal_path(db)]
        seated = [m["uid"] for g in proposal["groups"] for m in g["members"]]
        assert "demo-001" not in seated + proposal["unseated"]

    def test_writes_no_ronda(self):
        db = FakeFirestore(invented_sign_ups())

        proposals.propose(db, ADMIN, NOW)

        assert not [p for p in db.documents if p.startswith("rondas/")]

    def test_with_nobody_signed_up_proposes_no_groups_and_no_alternative(self):
        db = FakeFirestore()

        summary = proposals.propose(db, ADMIN, NOW)

        assert summary["groups"] == 0
        assert db.documents[proposal_path(db)]["rejectedAlternative"] is None


class TestDemoSignUps:
    """Two real members (invented ids that don't start with `demo-`) next to the demo set."""

    REAL = ("Xb3kQ9", "Pq7Lm2")

    def sign_ups(self) -> dict[str, dict]:
        real = {}
        for uid in self.REAL:
            real[f"users/{uid}"] = {
                "firstName": "Vecina",
                "ageBand": "60-69",
                "barrio": "solymar-sur",
                "pretexts": ["mate"],
                "slots": ["sat-afternoon"],
            }
            real[f"users/{uid}/private/eligible"] = {"seatIds": ["solymar-sur_mate_sat-afternoon"]}
        real["avoid/Pq7Lm2_Xb3kQ9"] = {"uidA": "Pq7Lm2", "uidB": "Xb3kQ9"}
        real["avoid/Xb3kQ9_demo-001"] = {"uidA": "Xb3kQ9", "uidB": "demo-001"}
        return invented_sign_ups() | real

    def solver_input(self, monkeypatch) -> dict:
        """What `propose` hands the solver, which answers with no groups."""
        seen = []

        def solve(data):
            seen.append(data)
            return {
                "status": "optimal",
                "proposals": [],
                "unseated": [],
                "rejectedAlternative": None,
            }

        monkeypatch.setattr(proposals, "solve", solve)
        proposals.propose(FakeFirestore(self.sign_ups()), ADMIN, NOW)
        [data] = seen
        return data

    def test_on_the_real_project_never_reach_the_solver(self, monkeypatch):
        on_the_real_project(monkeypatch)

        data = self.solver_input(monkeypatch)

        assert [person["uid"] for person in data["people"]] == sorted(self.REAL)
        assert data["avoidPairs"] == [["Pq7Lm2", "Xb3kQ9"]]

    def test_on_the_real_project_alone_they_make_no_group(self, monkeypatch):
        on_the_real_project(monkeypatch)
        db = FakeFirestore(invented_sign_ups())

        summary = proposals.propose(db, ADMIN, NOW)

        assert (summary["groups"], summary["unseated"]) == (0, 0)

    @pytest.mark.parametrize("where", [under_the_emulator, on_a_demo_project])
    def test_under_the_emulator_and_on_a_demo_project_join_everyone_else(self, monkeypatch, where):
        where(monkeypatch)

        data = self.solver_input(monkeypatch)

        uids = [person["uid"] for person in data["people"]]
        assert len(uids) == 32
        assert set(self.REAL) < set(uids)
        assert ["demo-005", "demo-006"] in data["avoidPairs"]
        assert ["Xb3kQ9", "demo-001"] in data["avoidPairs"]


class TestProposalDocument:
    def result(self, members: list[str], unseated: list[str]) -> dict:
        return {
            "status": "optimal",
            "proposals": [
                {
                    "id": "lagomar-sur_mate_sat-afternoon",
                    "barrio": "lagomar-sur",
                    "pretext": "mate",
                    "slot": "sat-afternoon",
                    "members": [
                        {"uid": uid, "ageBand": "60-69", "distanceBlocks": 2} for uid in members
                    ],
                    "checks": {"plusOneTogether": True},
                }
            ],
            "unseated": unseated,
            "rejectedAlternative": None,
        }

    def users(self) -> dict[str, dict]:
        return {
            "ana": {"firstName": "Ana", "plusOneUid": "beto"},
            "beto": {"firstName": "Beto"},
            "cora": {"firstName": "Cora", "plusOneUid": "dani"},
            "dani": {"firstName": "Dani"},
            "eva": {"firstName": "Eva", "plusOneUid": "not-signed-up"},
        }

    def test_says_whether_each_plus_one_who_signed_up_is_in_the_same_group(self):
        document = proposals.proposal_document(
            self.result(["ana", "beto", "cora", "eva"], unseated=["dani"]), self.users(), ADMIN, NOW
        )

        members = {m["uid"]: m for m in document["groups"][0]["members"]}
        assert members["ana"]["plusOneInGroup"] is True
        assert members["cora"]["plusOneInGroup"] is False
        assert "plusOneInGroup" not in members["beto"]
        assert "plusOneInGroup" not in members["eva"]
        assert document["unseated"] == ["dani"]

    def test_names_who_is_left_out_by_first_name_barrio_and_slots(self):
        users = self.users() | {
            "dani": {
                "firstName": "Dani",
                "ageBand": "30-39",
                "barrio": "solymar-sur",
                "slots": ["sat-afternoon", "tue-evening"],
                "pretexts": ["mate"],
                "brings": ["pan"],
                "terms": {},
            }
        }

        document = proposals.proposal_document(
            self.result(["ana", "beto"], unseated=["dani", "eva"]), users, ADMIN, NOW
        )

        assert document["unseatedPeople"] == [
            {
                "uid": "dani",
                "firstName": "Dani",
                "barrio": "solymar-sur",
                "slots": ["sat-afternoon", "tue-evening"],
                "pretexts": ["mate"],
            },
            {"uid": "eva", "firstName": "Eva", "barrio": "", "slots": [], "pretexts": []},
        ]


class TestApprove:
    def proposed(self) -> tuple[FakeFirestore, str]:
        db = FakeFirestore(invented_sign_ups())
        return db, proposals.propose(db, ADMIN, NOW)["proposalId"]

    def test_writes_a_ronda_and_its_members_per_group_and_marks_it_approved(self):
        db, proposal_id = self.proposed()
        proposal = db.documents[f"proposals/{proposal_id}"]

        result = proposals.approve(db, proposal_id, ADMIN, NOW)

        assert len(result["rondaIds"]) == len(proposal["groups"])
        first_id, group = result["rondaIds"][0], proposal["groups"][0]
        day, time = group["slot"].split("-")
        assert db.documents[f"rondas/{first_id}"] == {
            "seatId": group["id"],
            "pretext": group["pretext"],
            "barrio": group["barrio"],
            "slot": {"day": day, "time": time},
            "size": len(group["members"]),
            "status": "forming",
            "openSeatFromWeek": 4,
            "createdAt": NOW,
        }
        uid = group["members"][0]["uid"]
        assert db.documents[f"rondas/{first_id}/members/{uid}"] == {
            "brings": ["pan"],
            "state": "active",
            "joinedAt": NOW,
        }
        assert db.documents[f"users/{uid}/rondas/{first_id}"] == {"joinedAt": NOW}
        approved = db.documents[f"proposals/{proposal_id}"]
        assert approved["status"] == "approved"
        assert approved["rondaIds"] == result["rondaIds"]
        assert approved["approvedBy"] == ADMIN

    def test_seats_every_proposed_member_once(self):
        db, proposal_id = self.proposed()
        proposal = db.documents[f"proposals/{proposal_id}"]

        proposals.approve(db, proposal_id, ADMIN, NOW)

        member_docs = [p for p in db.documents if p.startswith("rondas/") and "/members/" in p]
        proposed = [m["uid"] for g in proposal["groups"] for m in g["members"]]
        assert sorted(p.rsplit("/", 1)[1] for p in member_docs) == sorted(proposed)

    def test_a_member_without_a_profile_any_more_joins_with_nothing_to_bring(self):
        db, proposal_id = self.proposed()
        uid = db.documents[f"proposals/{proposal_id}"]["groups"][0]["members"][0]["uid"]
        del db.documents[f"users/{uid}"]

        [first, *_] = proposals.approve(db, proposal_id, ADMIN, NOW)["rondaIds"]

        assert db.documents[f"rondas/{first}/members/{uid}"]["brings"] == []

    def test_refuses_twice(self):
        db, proposal_id = self.proposed()
        proposals.approve(db, proposal_id, ADMIN, NOW)

        with pytest.raises(proposals.ProposalError) as error:
            proposals.approve(db, proposal_id, ADMIN, NOW)
        assert error.value.code == "failed-precondition"

    def test_refuses_an_unknown_proposal(self):
        with pytest.raises(proposals.ProposalError) as error:
            proposals.approve(FakeFirestore(), "nope", ADMIN, NOW)
        assert error.value.code == "not-found"

    def test_refuses_a_proposal_with_no_groups(self):
        db = FakeFirestore()
        proposal_id = proposals.propose(db, ADMIN, NOW)["proposalId"]

        with pytest.raises(proposals.ProposalError) as error:
            proposals.approve(db, proposal_id, ADMIN, NOW)
        assert error.value.code == "failed-precondition"


class TestUndoApproval:
    def test_deletes_the_rondas_and_puts_the_proposal_back_to_pending(self):
        db = FakeFirestore(invented_sign_ups())
        proposal_id = proposals.propose(db, ADMIN, NOW)["proposalId"]
        pending = dict(db.documents[f"proposals/{proposal_id}"])
        proposals.approve(db, proposal_id, ADMIN, NOW)

        proposals.undo_approval(db, proposal_id)

        assert not [p for p in db.documents if p.startswith("rondas/")]
        assert not [p for p in db.documents if "/rondas/" in p]
        assert db.documents[f"proposals/{proposal_id}"] == pending

    def test_refuses_a_pending_proposal(self):
        db = FakeFirestore(invented_sign_ups())
        proposal_id = proposals.propose(db, ADMIN, NOW)["proposalId"]

        with pytest.raises(proposals.ProposalError):
            proposals.undo_approval(db, proposal_id)
