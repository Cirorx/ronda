"""Ronda's scheduled jobs: one hourly dispatcher runs them all, and the admin's `run_job` runs
one by name with an injected clock (docs/ARCHITECTURE.md § Code boundaries).

Every job is a plain `run_<job>(db, now, ...)` that is safe to run again: it decides from `now`
and what it already wrote whether anything is due. `JOBS` adapts each to one call shape; a job
that needs only `(db, now)` joins as `lambda db, now, context: module.run_x(db, now)`.
"""

import logging
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime

import attendance
import fcm
import rain
import rsvp
import seguimos

log = logging.getLogger(__name__)


@dataclass(frozen=True)
class Context:
    """What a job may need besides the database and the clock."""

    send: Callable[[list[dict]], list[str]]
    """Delivers FCM HTTP v1 message dicts; one outcome per message (fcm.send)."""

    app_url: str = ""
    """Where a web notification opens the app."""

    force: bool = False
    """The admin asked for it now: skip the job's own timing (never its gates)."""


def context(*, force: bool = False) -> Context:
    """The context the dispatcher and `run_job` run with: real FCM, the project's app URL."""
    return Context(send=fcm.send, app_url=fcm.app_url(), force=force)


JOBS: dict[str, Callable[[object, datetime, Context], dict]] = {
    "rsvp_push": lambda db, now, context: rsvp.run_rsvp_push(
        db, now, send=context.send, app_url=context.app_url, force=context.force
    ),
    "seguimos_ask": lambda db, now, context: seguimos.run_seguimos_ask(
        db, now, send=context.send, app_url=context.app_url, force=context.force
    ),
    "rain_check": lambda db, now, context: rain.run_rain_check(
        db, now, send=context.send, app_url=context.app_url, force=context.force
    ),
    "attendance_ask": lambda db, now, context: attendance.run_attendance_ask(
        db, now, send=context.send, app_url=context.app_url, force=context.force
    ),
}


class UnknownJob(Exception):
    """No job by that name."""


def run(name: str, db, now: datetime, context: Context) -> dict:
    """Runs job `name` once at `now` and returns its counts."""
    if name not in JOBS:
        raise UnknownJob(name)
    return JOBS[name](db, now, context)


def run_due(db, now: datetime, context: Context) -> dict[str, dict | str]:
    """The hourly dispatcher's body: every job at `now`. One job failing doesn't stop the rest;
    it is logged by its error's type only (a message could carry a token)."""
    results: dict[str, dict | str] = {}
    for name in JOBS:
        try:
            results[name] = run(name, db, now, context)
        except Exception as error:
            log.error("job %s failed: %s", name, type(error).__name__)
            results[name] = "failed"
    return results
