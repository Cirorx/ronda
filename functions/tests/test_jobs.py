"""jobs.py: the registry, one job by name, and the dispatcher's run of all of them."""

from datetime import UTC, datetime

import pytest

import fcm
import jobs
import rsvp
from tests.fake_firestore import FakeFirestore
from tests.test_rsvp import RONDA, THU_19, Sender, documents

CONTEXT = jobs.Context(send=Sender(), app_url="https://example.test/app/ronda")


def test_the_default_context_sends_through_fcm_to_the_projects_app(monkeypatch):
    monkeypatch.setenv("GCLOUD_PROJECT", "demo-ronda")

    context = jobs.context(force=True)

    assert context == jobs.Context(
        send=fcm.send, app_url="https://demo-ronda.firebaseapp.com/app/ronda", force=True
    )


def test_runs_the_rsvp_push_by_name_with_the_context():
    db = FakeFirestore(documents())
    sender = Sender()

    counts = jobs.run("rsvp_push", db, THU_19, jobs.Context(send=sender, force=False))

    assert counts["pushed"] == 1
    assert len(sender.messages) == 3


def test_passes_force_through():
    db = FakeFirestore(documents())
    early = datetime(2026, 10, 28, 15, 0, tzinfo=UTC)

    counts = jobs.run("rsvp_push", db, early, jobs.Context(send=Sender(), force=True))

    assert counts["pushed"] == 1


def test_refuses_an_unknown_job():
    with pytest.raises(jobs.UnknownJob):
        jobs.run("nope", FakeFirestore(), THU_19, CONTEXT)


def test_the_dispatcher_runs_every_job_and_survives_one_failing(monkeypatch, caplog):
    calls = []
    monkeypatch.setitem(jobs.JOBS, "boom", lambda db, now, context: 1 / 0)
    monkeypatch.setitem(jobs.JOBS, "fine", lambda db, now, context: calls.append(now) or {"n": 1})
    db = FakeFirestore(documents())

    results = jobs.run_due(db, THU_19, CONTEXT)

    assert results["boom"] == "failed"
    assert results["fine"] == {"n": 1}
    assert results["rsvp_push"]["pushed"] == 1
    assert calls == [THU_19]
    assert "ZeroDivisionError" in caplog.text
    assert f"rondas/{RONDA}/weeks/{rsvp.iso_week(datetime(2026, 10, 31).date())}" in db.documents
