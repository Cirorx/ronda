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
import auto_form
import bench
import buddy
import day_of
import despues
import donde_queda
import fcm
import first_visit
import handoff
import rain
import removals
import rotation
import rsvp
import seat_catalog
import seguimos
import shared_plans
import waitlists
import weekly_card

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
    "bench": lambda db, now, context: bench.run_bench(
        db, now, send=context.send, app_url=context.app_url, force=context.force
    ),
    "waitlists": lambda db, now, context: waitlists.run_waitlists(db, now),
    # The weekly loop's code jobs (#47, #50): fixed rules, no model.
    "assign_hosts": lambda db, now, context: rotation.run_assign_hosts(db, now),
    "handoff": lambda db, now, context: handoff.run_handoff(
        db, now, send=context.send, app_url=context.app_url, force=context.force
    ),
    "prompt_buddy": lambda db, now, context: buddy.run_prompt_buddy(
        db, now, send=context.send, app_url=context.app_url, force=context.force
    ),
    "despues_sweep": lambda db, now, context: despues.run_despues_sweep(db, now),
    # Así va a ser (#70): newcomers' welcomes for the upcoming meeting; sends nothing.
    "first_visit": lambda db, now, context: first_visit.run_first_visit(db, now),
    # ¿Dónde queda? (#58): the weekly photo game's turns and reveal; sends nothing.
    "donde_queda": lambda db, now, context: donde_queda.run_donde_queda(db, now),
    # ¿Alguien se suma? (#57): deletes shared plans once their time has passed; sends nothing.
    "shared_plans": lambda db, now, context: shared_plans.run_shared_plans(db, now),
    # [Sacar de Ronda] (#71): the neutral notice held overnight goes out at the next hour.
    "removal_notices": lambda db, now, context: removals.run_removal_notices(
        db, now, send=context.send, app_url=context.app_url
    ),
    # The weekly card the organiser composes (#62), for rondas with the switch on; sends nothing.
    "weekly_card": lambda db, now, context: weekly_card.run_weekly_card(
        db, now, send=context.send, app_url=context.app_url, force=context.force
    ),
    # The seat catalogue phones match needs against; writes only when it changed.
    "seat_catalog": lambda db, now, context: seat_catalog.run_seat_catalog(
        db, now, force=context.force
    ),
    # Rondas that form themselves: the solver, the agent's setup, approval after the hold.
    "auto_form": lambda db, now, context: auto_form.run_auto_form(
        db, now, send=context.send, app_url=context.app_url
    ),
    # The day-of reminder with the next city buses (#65), for every ronda not switched off.
    "day_of": lambda db, now, context: day_of.run_day_of(
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
