"""auto_form.py: rondas that form themselves, over the Firestore stand-in and a scripted model.
Two invented neighbours want mate in Cordón on Thursday afternoons (tests/auto_form_fakes.py)."""

from datetime import timedelta

import pytest

import auto_form
import jobs
import proposals
import rsvp
from tests.auto_form_fakes import MON_10, MON_23, PEOPLE, PLAZA, SEAT, TUE_09, sign_ups
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import ScriptedModel, call, turn
from tests.test_rsvp import Sender

LATER = MON_10 + timedelta(minutes=60)
REASON = "La plaza queda cerca de los dos; abre m2."


def agent() -> ScriptedModel:
    return ScriptedModel(
        [
            turn(call("propose_setup", place_id=PLAZA, hour="16:30", host="m2", reason=REASON)),
            turn(content="Listo."),
        ]
    )


def run(db, now, *, send=None, model=None) -> dict:
    return auto_form.run_auto_form(db, now, send=send or Sender(), model=model or agent())


def all_proposals(db) -> dict[str, dict]:
    return {p[10:]: d for p, d in db.documents.items() if p.startswith("proposals/")}


def auto_proposal(db) -> tuple[str, dict]:
    [(proposal_id, proposal)] = [(i, p) for i, p in all_proposals(db).items() if p.get("auto")]
    return proposal_id, proposal


def rondas(db) -> dict[str, dict]:
    return {
        p[7:]: d for p, d in db.documents.items() if p.count("/") == 1 and p.startswith("rondas/")
    }


class TestConfig:
    def test_defaults_to_on_with_an_hour_of_hold(self):
        assert auto_form.config(FakeFirestore()) == auto_form.Config(True, 60)

    def test_reads_the_admins_switch_and_hold(self):
        db = FakeFirestore({"config/auto_form": {"enabled": False, "holdMinutes": 0}})

        assert auto_form.config(db) == auto_form.Config(False, 0)

    @pytest.mark.parametrize("hold", [-1, 1441, True, "60", 1.5])
    def test_a_malformed_field_reads_as_its_default(self, hold):
        db = FakeFirestore({"config/auto_form": {"enabled": "yes", "holdMinutes": hold}})

        assert auto_form.config(db) == auto_form.Config(True, 60)


class TestForming:
    def test_writes_an_auto_proposal_with_the_agents_setup_and_the_hold(self):
        db = FakeFirestore(sign_ups())

        counts = run(db, MON_10)

        _, proposal = auto_proposal(db)
        assert proposal["status"] == "pending"
        assert proposal["approveAt"] == LATER
        assert proposal["createdBy"] == "auto_form"
        [group] = proposal["groups"]
        assert group["id"] == SEAT
        assert group["setup"]["by"] == "agent"
        assert group["setup"]["reason"] == "La plaza queda cerca de los dos; abre Beto."
        assert "autoBlocked" not in proposal
        assert (counts["formed"], counts["agent"], counts["approved"]) == (1, 1, 0)
        assert not rondas(db)

    def test_supersedes_the_older_pending_proposals_that_name_the_same_people(self):
        db = FakeFirestore(sign_ups())
        db.documents["proposals/stale"] = {
            "status": "pending",
            "groups": [],
            "unseated": ["demo-af-1"],
        }
        db.documents["proposals/other"] = {"status": "pending", "groups": [], "unseated": ["x"]}
        db.documents["proposals/done"] = {
            "status": "approved",
            "groups": [],
            "unseated": ["demo-af-2"],
        }

        run(db, MON_10)

        proposal_id, _ = auto_proposal(db)
        stale = db.documents["proposals/stale"]
        assert (stale["status"], stale["supersededBy"], stale["supersededAt"]) == (
            "superseded",
            proposal_id,
            MON_10,
        )
        assert db.documents["proposals/other"]["status"] == "pending"
        assert db.documents["proposals/done"]["status"] == "approved"

    def test_forms_nothing_while_an_auto_proposal_is_still_pending(self):
        db = FakeFirestore(sign_ups())
        run(db, MON_10)

        counts = run(db, MON_10 + timedelta(minutes=30))

        assert counts["waiting"] == 1 and counts["formed"] == 0

    def test_writes_nothing_when_the_solver_seats_nobody(self):
        db = FakeFirestore(sign_ups())
        del db.documents["users/demo-af-2"]

        counts = run(db, MON_10)

        assert not all_proposals(db) and counts["formed"] == 0

    def test_without_a_setup_the_proposal_waits_for_the_admin(self):
        db = FakeFirestore(sign_ups(places=False))

        counts = run(db, MON_10)

        _, proposal = auto_proposal(db)
        assert proposal["groups"][0]["setup"] is None
        assert proposal["autoBlocked"] == "setup"
        assert counts["unset"] == 1

        run(db, LATER)

        assert not rondas(db)


class TestApproval:
    def test_once_the_hold_passes_the_ronda_is_complete(self):
        db = FakeFirestore(sign_ups())
        run(db, MON_10)

        counts = run(db, LATER)

        proposal_id, proposal = auto_proposal(db)
        assert proposal["status"] == "approved" and proposal["approvedBy"] == "auto_form"
        [ronda_id] = proposal["rondaIds"]
        ronda = rondas(db)[ronda_id]
        assert ronda["place"] == {"name": "la Plaza Inventada"}
        assert ronda["slot"] == {"day": "thu", "time": "afternoon", "hour": "16:30"}
        assert (ronda["hosts"]["anfitrionName"], ronda["hosts"]["colaName"]) == ("Beto", "Ana")
        assert rsvp.to_confirm(ronda) == ""
        assert rsvp.ronda_line(ronda) == "Jueves 16:30 · mate en la rambla · la Plaza Inventada"
        for uid in PEOPLE:
            assert f"users/{uid}/rondas/{ronda_id}" in db.documents
        assert db.documents[f"agent_runs/auto_{proposal_id}_1"]["rondaId"] == ronda_id
        assert counts["approved"] == 1

    def test_a_hold_of_zero_approves_in_the_same_run(self):
        db = FakeFirestore(sign_ups())
        db.documents["config/auto_form"] = {"enabled": True, "holdMinutes": 0}

        counts = run(db, MON_10)

        assert (counts["formed"], counts["approved"]) == (1, 1)
        assert auto_proposal(db)[1]["status"] == "approved"

    def test_before_the_hold_passes_nothing_is_approved(self):
        db = FakeFirestore(sign_ups())
        run(db, MON_10)

        run(db, LATER - timedelta(minutes=1))

        assert auto_proposal(db)[1]["status"] == "pending"

    def test_switched_off_nothing_forms_or_approves(self):
        db = FakeFirestore(sign_ups())
        run(db, MON_10)
        db.documents["config/auto_form"] = {"enabled": False, "holdMinutes": 60}

        run(db, LATER)

        assert auto_proposal(db)[1]["status"] == "pending"

        db = FakeFirestore({**sign_ups(), "config/auto_form": {"enabled": False}})
        run(db, MON_10)
        assert not all_proposals(db)


class TestBlockers:
    def formed(self) -> tuple[FakeFirestore, str]:
        db = FakeFirestore(sign_ups())
        run(db, MON_10)
        return db, auto_proposal(db)[0]

    def test_a_stopped_proposal_waits_for_a_manual_aprobar(self):
        db, proposal_id = self.formed()
        proposals.stop(db, proposal_id, "admin", MON_10)

        counts = run(db, LATER)

        proposal = db.documents[f"proposals/{proposal_id}"]
        assert (proposal["status"], proposal["autoBlocked"]) == ("pending", "stopped")
        assert counts["blocked"] == 1 and not rondas(db)

        proposals.approve(db, proposal_id, "admin", LATER)

        [ronda] = rondas(db).values()
        assert ronda["place"] == {"name": "la Plaza Inventada"}

    @pytest.mark.parametrize(
        ("documents", "why"),
        [
            (
                {
                    "reports/r1": {
                        "status": "open",
                        "reporterUid": "demo-x",
                        "aboutUid": "demo-af-1",
                    }
                },
                "report",
            ),
            ({"avoid/p1": {"uidA": "demo-af-2", "uidB": "demo-x"}}, "avoid"),
            (
                {
                    "rondas/r9": {"status": "active"},
                    "rondas/r9/members/demo-af-1": {"state": "active"},
                },
                "seated",
            ),
            ({"removed/demo-af-2": {"firstName": "Beto"}}, "removed"),
        ],
    )
    def test_never_approves_itself_when_a_member_is_in_a_safety_case_or_placed(
        self, documents, why
    ):
        db, proposal_id = self.formed()
        db.documents.update(documents)

        run(db, LATER)

        proposal = db.documents[f"proposals/{proposal_id}"]
        assert (proposal["status"], proposal["autoBlocked"]) == ("pending", why)
        assert proposal["autoBlockedAt"] == LATER
        assert set(rondas(db)) <= {"r9"}

    def test_an_archived_report_blocks_nothing(self):
        db, proposal_id = self.formed()
        db.documents["reports/r1"] = {
            "status": "archived",
            "reporterUid": "demo-af-1",
            "aboutUid": "",
        }

        run(db, LATER)

        assert db.documents[f"proposals/{proposal_id}"]["status"] == "approved"

    def test_an_incomplete_setup_blocks_it(self):
        db, proposal_id = self.formed()
        db.documents[f"proposals/{proposal_id}"]["groups"][0]["setup"]["hour"] = ""

        run(db, LATER)

        assert db.documents[f"proposals/{proposal_id}"]["autoBlocked"] == "setup"

    def test_undoing_an_auto_approval_stops_it(self):
        db, proposal_id = self.formed()
        run(db, LATER)

        proposals.undo_approval(db, proposal_id, "admin", LATER)
        run(db, LATER + timedelta(hours=1))

        proposal = db.documents[f"proposals/{proposal_id}"]
        assert (proposal["status"], proposal["autoBlocked"]) == ("pending", "stopped")
        assert "notice" not in proposal and not rondas(db)


class TestTellingTheMembers:
    def test_an_approval_by_day_tells_each_member_once_through_the_gates(self):
        db = FakeFirestore(sign_ups())
        sender = Sender()
        run(db, MON_10, send=sender)

        run(db, LATER, send=sender)
        run(db, LATER + timedelta(hours=1), send=sender)

        assert sender.tokens == ["tok-demo-af-1", "tok-demo-af-2"]
        body = sender.messages[0]["data"]["body"]
        assert body.startswith("Hola, Ana. Soy un programa.")
        assert body.endswith(
            "Ya tenés ronda: Jueves 16:30 · mate en la rambla · la Plaza Inventada. "
            "Los detalles están en Mi ronda."
        )
        assert sender.messages[0]["data"]["type"] == "notice"
        proposal = auto_proposal(db)[1]
        assert (proposal["notice"], proposal["noticeAt"]) == ("sent", LATER)

    def test_a_night_approval_is_announced_at_nine(self):
        db = FakeFirestore({**sign_ups(), "config/auto_form": {"enabled": True, "holdMinutes": 0}})
        sender = Sender()

        counts = run(db, MON_23, send=sender)

        assert auto_proposal(db)[1]["status"] == "approved"
        assert auto_proposal(db)[1]["notice"] == "pending"
        assert sender.messages == [] and counts["held"] == 1

        run(db, TUE_09 - timedelta(hours=1), send=sender)
        assert sender.messages == []

        counts = run(db, TUE_09, send=sender)

        assert sender.tokens == ["tok-demo-af-1", "tok-demo-af-2"]
        assert counts["told"] == 2
        [ronda_id] = auto_proposal(db)[1]["rondaIds"]
        trace = db.documents[f"agent_runs/{ronda_id}_formed"]
        assert (trace["job"], trace["status"]) == ("auto_form", "done")

    def test_the_notices_still_go_out_with_the_switch_off(self):
        db = FakeFirestore({**sign_ups(), "config/auto_form": {"enabled": True, "holdMinutes": 0}})
        run(db, MON_23)
        db.documents["config/auto_form"] = {"enabled": False}
        sender = Sender()

        run(db, TUE_09, send=sender)

        assert len(sender.messages) == 2

    def test_a_manual_approval_tells_nobody(self):
        db = FakeFirestore(sign_ups())
        proposal_id = proposals.propose(db, "admin", MON_10)["proposalId"]
        proposals.approve(db, proposal_id, "admin", MON_10)
        db.documents["config/auto_form"] = {"enabled": False}
        sender = Sender()

        run(db, LATER, send=sender)

        assert sender.messages == []
        assert "notice" not in db.documents[f"proposals/{proposal_id}"]


def test_the_dispatcher_runs_it():
    assert "auto_form" in jobs.JOBS
    db = FakeFirestore({"config/auto_form": {"enabled": False}})

    counts = jobs.run("auto_form", db, MON_10, jobs.Context(send=Sender()))

    assert counts["formed"] == 0


def test_builds_the_model_from_the_environment_only_when_a_group_needs_it(monkeypatch):
    built = []
    monkeypatch.setattr(auto_form, "from_environment", lambda **kw: built.append(kw) or agent())
    db = FakeFirestore(sign_ups())

    auto_form.run_auto_form(db, MON_10, send=Sender())
    assert built == [{"timeout": 30}]

    auto_form.run_auto_form(FakeFirestore(), MON_10, send=Sender())
    assert len(built) == 1
