"""Rondas that form themselves (docs/PRODUCT.md § Joining and forming rondas, "Solver +
approval"; approved by the owner on 2026-11-02).

The hourly job `auto_form` (`run_auto_form`, jobs.JOBS), while `config/auto_form.enabled`:
1. **Approves what is due.** A pending auto proposal whose `approveAt` passed is approved
   through `proposals.approve`, the path behind [Aprobar], which also writes each ronda's place,
   hour and hosts from its setup, unless something blocks it (`blocker`): the admin stopped it
   ([Frenar]), a group's setup is incomplete, any member has an open safety report or an avoid
   pair, or a member is seated elsewhere or out of Ronda by now. A blocked proposal gets
   `autoBlocked` and waits for a manual Aprobar.
2. **Forms.** When no auto proposal is still pending (one waits for its hold, or for the admin),
   it runs the solver on the same input and checks as "Armar las rondas"
   (`proposals.solve_sign_ups`) and, when that seats anyone, writes a proposal with `auto:
   true` and `approveAt = now + holdMinutes`, each group with the organiser's setup
   (auto_setup.py), and supersedes the older pending proposals it covers. A setup that neither
   the agent nor code could make leaves the proposal `autoBlocked: setup`.
3. **Tells the members.** Every member of an approved auto proposal gets one notice, «Ya tenés
   ronda: …», through the gates (kind `notice`): from 21:00 to 09:00 it waits, so an approval at
   night is announced at 09:00. `proposals/{id}.notice` goes from `pending` to `sent`.

With the switch off the job only sends the notices still pending. A hold of 0 approves in the
same run, for the demo.

`config/auto_form`: `{enabled: bool, holdMinutes: int, updatedAt, updatedBy}`, read by the
admin only (firestore.rules) and written only by `set_config` (`set_auto_form`, admin); a
missing or malformed field reads as the default (`ENABLED`, `HOLD_MINUTES`).

On `proposals/{id}`, besides proposals.py's fields: auto, approveAt, groups[n].setup
(auto_setup.py), stoppedAt and stoppedBy, autoBlocked (`BLOCKERS`) and autoBlockedAt, notice.
"""

import logging
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timedelta

import auto_setup
import proposals
import reports
import rsvp
import safety
from organiser import gates, outbox
from organiser.model import ModelClient, from_environment
from organiser.trace import Trace

log = logging.getLogger(__name__)

JOB = "auto_form"
CONFIG = "config/auto_form"
ENABLED = True
HOLD_MINUTES = 60
MAX_HOLD_MINUTES = 24 * 60
"""The longest hold the rules allow: a day."""

STOPPED, SETUP, REPORT, AVOID, SEATED, REMOVED = (
    "stopped",
    "setup",
    "report",
    "avoid",
    "seated",
    "removed",
)
BLOCKERS = (STOPPED, SETUP, REPORT, AVOID, SEATED, REMOVED)
"""Why an auto proposal doesn't approve itself, in the order they are checked."""

SENT = "sent"
NOTICE_TITLE = "Ronda"
NOTICE_TYPE = "notice"
"""`data.type` of the push; the phone draws it plain and a tap opens Mi ronda."""


@dataclass(frozen=True)
class Config:
    enabled: bool = ENABLED
    hold_minutes: int = HOLD_MINUTES


def config(db) -> Config:
    """`config/auto_form`, each field falling back to its default when absent or malformed."""
    snapshot = db.document(CONFIG).get()
    fields = (snapshot.to_dict() or {}) if snapshot.exists else {}
    enabled, hold = fields.get("enabled"), fields.get("holdMinutes")
    return Config(
        enabled=enabled if isinstance(enabled, bool) else ENABLED,
        hold_minutes=hold
        if isinstance(hold, int) and not isinstance(hold, bool) and 0 <= hold <= MAX_HOLD_MINUTES
        else HOLD_MINUTES,
    )


class ConfigError(Exception):
    """A config the callable refuses; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def set_config(db, data: object, admin_uid: str, now: datetime) -> dict:
    """Writes `config/auto_form` from `{enabled: bool, holdMinutes: int 0 to a day}`
    (`set_auto_form`, admin); returns what it wrote."""
    data = data if isinstance(data, dict) else {}
    enabled, hold = data.get("enabled"), data.get("holdMinutes")
    if not isinstance(enabled, bool):
        raise ConfigError("invalid-argument", "enabled is true or false")
    if not isinstance(hold, int) or isinstance(hold, bool) or not 0 <= hold <= MAX_HOLD_MINUTES:
        raise ConfigError("invalid-argument", f"holdMinutes is 0 to {MAX_HOLD_MINUTES}")
    db.document(CONFIG).set(
        {"enabled": enabled, "holdMinutes": hold, "updatedAt": now, "updatedBy": admin_uid}
    )
    return {"enabled": enabled, "holdMinutes": hold}


def notice_text(ronda: dict) -> str:
    """ "Ya tenés ronda: Jueves 16:00 · mate en la rambla · la plaza del barrio. Los detalles están
    en Mi ronda." """
    return f"Ya tenés ronda: {rsvp.ronda_line(ronda)}. Los detalles están en Mi ronda."


def _members(proposal: dict) -> set[str]:
    return {m["uid"] for group in proposal["groups"] for m in group["members"]}


def _open_reports(db) -> set[str]:
    """Everyone an open report is from or about."""
    found = set()
    for snapshot in db.collection("reports").stream():
        report = snapshot.to_dict() or {}
        if report.get("status") == reports.OPEN:
            found |= {report.get("reporterUid"), report.get("aboutUid")} - {None, ""}
    return found


def blocker(db, proposal: dict) -> str:
    """Why `proposal` must not approve itself now (`BLOCKERS`), or "" when nothing does."""
    members = _members(proposal)
    if proposal.get("stoppedAt") is not None:
        return STOPPED
    if not all(auto_setup.complete(group.get("setup")) for group in proposal["groups"]):
        return SETUP
    if members & _open_reports(db):
        return REPORT
    if members & set(safety.apart(db)):
        return AVOID
    if members & rsvp.seated_uids(db):
        return SEATED
    if members & safety.removed(db):
        return REMOVED
    return ""


def _pending_auto(db) -> list[tuple[str, dict]]:
    return [
        (snapshot.id, proposal)
        for snapshot in db.collection("proposals").stream()
        if (proposal := snapshot.to_dict() or {}).get("status") == proposals.PENDING
        and proposal.get("auto") is True
    ]


def approve_due(db, now: datetime, counts: dict) -> None:
    """Approves every pending auto proposal whose hold is over, or marks why it can't."""
    for proposal_id, proposal in _pending_auto(db):
        if proposal.get("autoBlocked") or proposal.get("approveAt", now) > now:
            continue
        if why := blocker(db, proposal):
            db.document(f"proposals/{proposal_id}").update(
                {"autoBlocked": why, "autoBlockedAt": now}
            )
            counts["blocked"] += 1
            continue
        proposals.approve(db, proposal_id, JOB, now)
        counts["approved"] += 1


def form(
    db, now: datetime, hold_minutes: int, get_model: Callable[[], ModelClient], counts: dict
) -> None:
    """Writes one auto proposal for the current sign-ups when nothing auto is pending and the
    solver seats anyone."""
    if _pending_auto(db):
        counts["waiting"] += 1
        return
    result, users = proposals.solve_sign_ups(db)
    if not result["proposals"]:
        return
    document = proposals.proposal_document(result, users, JOB, now)
    reference = db.collection("proposals").document()
    for n, group in enumerate(document["groups"], start=1):
        setup = auto_setup.set_up(
            db,
            f"auto_{reference.id}_{n}",
            auto_setup.group_of(db, group, users, now),
            now,
            get_model,
        )
        group["setup"] = setup
        counts[setup["by"] if setup else "unset"] += 1
    document |= {"auto": True, "approveAt": now + timedelta(minutes=hold_minutes)}
    if not all(group["setup"] for group in document["groups"]):
        document |= {"autoBlocked": SETUP, "autoBlockedAt": now}
    reference.set(document)
    proposals.supersede(db, reference.id, document, now)
    counts["formed"] += 1


def tell_members(
    db, now: datetime, *, send: Callable[[list[dict]], list[str]], app_url: str, counts: dict
) -> None:
    """Sends «Ya tenés ronda» to every member of an approved auto proposal not told yet; outside
    the hours it waits for the next run inside them."""
    for snapshot in db.collection("proposals").stream():
        proposal = snapshot.to_dict() or {}
        if proposal.get("notice") != proposals.NOTICE_PENDING:
            continue
        if not rsvp.inside_gate(now):
            counts["held"] += 1
            continue
        week = rsvp.iso_week(rsvp.local(now).date())
        for ronda_id in proposal.get("rondaIds", []):
            ronda = db.document(f"rondas/{ronda_id}").get().to_dict() or {}
            members = rsvp.counted(rsvp._members(db, ronda_id))
            names = rsvp._first_names(db, members)
            trace = Trace(db, f"{ronda_id}_formed", ronda_id=ronda_id, week=week, now=now)
            trace.start(job=JOB, model="", forced=False)
            for uid in sorted(members):
                draft = outbox.prepare(
                    db,
                    outbox.Recipient(uid, names[uid]),
                    title=NOTICE_TITLE,
                    text=notice_text(ronda),
                    kind=gates.NOTICE,
                    week=week,
                    now=now,
                )
                outbox.deliver(
                    db, trace, draft, send=send, data={"type": NOTICE_TYPE}, link=app_url, now=now
                )
                counts["told"] += 1
            trace.finish("done")
        db.document(f"proposals/{snapshot.id}").update({"notice": SENT, "noticeAt": now})


def run_auto_form(
    db,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
    model: ModelClient | None = None,
) -> dict:
    """The hourly job (see the module). Returns counts."""
    counts = {
        "approved": 0,
        "blocked": 0,
        "formed": 0,
        "waiting": 0,
        auto_setup.AGENT: 0,
        auto_setup.CODE: 0,
        "unset": 0,
        "told": 0,
        "held": 0,
    }
    settings = config(db)
    if settings.enabled:
        models: list[ModelClient] = [model] if model else []

        def get_model() -> ModelClient:
            if not models:
                models.append(from_environment(timeout=30))
            return models[0]

        approve_due(db, now, counts)
        form(db, now, settings.hold_minutes, get_model, counts)
        approve_due(db, now, counts)
    tell_members(db, now, send=send, app_url=app_url, counts=counts)
    log.info("auto_form: %s", counts)
    return counts
