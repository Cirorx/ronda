"""[Sacar de Ronda] and [Dejar entrar de nuevo]: the admin takes the person a report is about out
of Ronda, and lets them back in (docs/PRODUCT.md § Safety; #71).

- `remove(db, data, now, send=...)` (`remove_from_ronda`, admin): `{reportId}`. In one
  transaction the person leaves every ronda they sit in (`state: left`, `leftAt`; their
  `users/{uid}/rondas` links go, so their phone finds no ronda), each ronda's `size` and
  "who's coming" view are rewritten, and `removed/{uid}` is written. Their pending offers of a
  freed seat are withdrawn. While `removed/{uid}` exists they are in no proposal, waiting list,
  bench or "Sumar a esta ronda" (safety.removed).
- They get one neutral notice, «Ya no estás en esta ronda.», that names no reporter and no
  reason, and only when they left a ronda. It passes the organiser's gates like every message
  (kind `notice`, not routine) and lands in the admin's trace, never in the acta. From 21:00
  to 09:00 it waits: the hourly `removal_notices` job (`run_removal_notices`) sends it at the
  next run inside the hours.
- `let_back_in(db, data)` (`let_back_in`, admin): `{uid}`. Deletes `removed/{uid}`; nobody is
  seated again and nothing is sent. They wait and match again like any sign-up.

`removed/{uid}`: firstName, reportId, at, rondaIds (the rondas they left), notice (pending |
sent | held | unreachable | skipped | none), noticeAt?. Read by the admin only (the queue's
"Fuera de Ronda"); written only here.
"""

from collections.abc import Callable
from datetime import datetime

import rsvp
import safety
from organiser import gates, outbox
from organiser.trace import Trace

JOB = "removal_notices"

NOTICE_TITLE = "Ronda"
NOTICE_TEXT = "Ya no estás en esta ronda."
"""The notice's words: neutral, with no reporter and no reason."""
NOTICE_TYPE = "notice"
"""`data.type` of the push; the phone draws it plain and a tap opens Mi ronda."""

PENDING, NONE = "pending", "none"
"""`removed/{uid}.notice` before it went out, and when there was nothing to tell."""


def _leave(db, uid: str, sitting: dict[str, dict], now: datetime) -> Callable:
    """The transaction that takes `uid` out of the rondas in `sitting`: member state, links,
    sizes and views. Every read comes before the first write, as Firestore requires."""
    today = rsvp.local(now).date()
    changed = {}
    for ronda_id, ronda in sitting.items():
        members = rsvp._members(db, ronda_id)
        members[uid] = {**members[uid], "state": "left"}
        meeting = rsvp.next_meeting(ronda["slot"]["day"], today)
        changed[ronda_id] = (
            members,
            meeting,
            db.document(f"rondas/{ronda_id}/weeks/{rsvp.iso_week(meeting)}"),
            rsvp._first_names(db, rsvp.counted(members)),
        )
    links = [link.id for link in db.collection(f"users/{uid}/rondas").stream()]

    def write(transaction) -> None:
        weeks = {
            ronda_id: week_ref.get(transaction=transaction)
            for ronda_id, (_, _, week_ref, _) in changed.items()
        }
        for ronda_id, (members, meeting, _, names) in changed.items():
            transaction.update(
                db.document(f"rondas/{ronda_id}/members/{uid}"), {"state": "left", "leftAt": now}
            )
            transaction.update(
                db.document(f"rondas/{ronda_id}"),
                {"size": sum(m.get("state", "active") in safety.SEATED for m in members.values())},
            )
            transaction.set(
                db.document(f"rondas/{ronda_id}/views/{rsvp.VIEW}"),
                rsvp.week_view(
                    meeting,
                    members,
                    names,
                    rsvp._rsvp(weeks[ronda_id]),
                    now,
                    rsvp.guests(weeks[ronda_id]),
                ),
            )
        for link in links:
            transaction.delete(db.document(f"users/{uid}/rondas/{link}"))

    return write


def _withdraw_offers(db, uid: str, now: datetime) -> None:
    for snapshot in db.collection(f"users/{uid}/offers").stream():
        if (snapshot.to_dict() or {}).get("status") == "pending":
            db.document(f"users/{uid}/offers/{snapshot.id}").update(
                {"status": "withdrawn", "closedAt": now}
            )


def remove(
    db,
    data: object,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
) -> dict:
    """[Sacar de Ronda] on report `reportId` (see the module). Returns `{uid, rondaIds,
    notice}`."""
    report_id, report = safety.reported(db, data)
    uid = report["aboutUid"]
    reference = db.document(f"removed/{uid}")
    if reference.get().exists:
        raise safety.SafetyError("already-exists", "already out of Ronda")
    sitting = safety.seated_in(db, uid)
    rsvp._in_transaction(db, _leave(db, uid, sitting, now))
    _withdraw_offers(db, uid, now)
    _out_of_welcomes(db, uid, sitting, now)
    left = sorted(sitting)
    record = {
        "firstName": rsvp._first_names(db, [uid])[uid],
        "reportId": report_id,
        "at": now,
        "rondaIds": left,
        "notice": PENDING if left else NONE,
    }
    reference.set(record)
    notice = deliver_notice(db, uid, record, now, send=send, app_url=app_url) if left else NONE
    return {"uid": uid, "rondaIds": left, "notice": notice}


def _out_of_welcomes(db, uid: str, sitting: dict[str, dict], now: datetime) -> None:
    """Drops `uid`'s own first visit in each ronda they left, and their pick to wait for
    someone else's (first_visit.welcome_ronda clears a waiter who left)."""
    import first_visit

    for ronda_id, ronda in sitting.items():
        db.document(f"rondas/{ronda_id}/welcomes/{uid}").delete()
        first_visit.welcome_ronda(db, ronda_id, ronda, now)


def deliver_notice(
    db,
    uid: str,
    record: dict,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
) -> str:
    """Sends `uid` the notice once it may go out, through the gates and into the trace of the
    first ronda they left. Outside the hours nothing is written and it stays pending."""
    if not rsvp.inside_gate(now):
        return PENDING
    ronda_id = record["rondaIds"][0]
    week = rsvp.iso_week(rsvp.local(now).date())
    trace = Trace(db, f"{ronda_id}_{week}_notice_{uid}", ronda_id=ronda_id, week=week, now=now)
    trace.start(job=JOB, model="", forced=False)
    draft = outbox.prepare(
        db,
        outbox.Recipient(uid, record.get("firstName", "")),
        title=NOTICE_TITLE,
        text=NOTICE_TEXT,
        kind=gates.NOTICE,
        week=week,
        now=now,
    )
    outcome = outbox.deliver(
        db, trace, draft, send=send, data={"type": NOTICE_TYPE}, link=app_url, now=now
    )
    trace.finish("done")
    db.document(f"removed/{uid}").update({"notice": outcome, "noticeAt": now})
    return outcome


def run_removal_notices(
    db,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
) -> dict:
    """The hourly job: every notice still pending goes out once inside the hours. Returns
    counts."""
    counts = {"sent": 0, "waiting": 0}
    for snapshot in db.collection("removed").stream():
        record = snapshot.to_dict() or {}
        if record.get("notice") != PENDING:
            continue
        outcome = deliver_notice(db, snapshot.id, record, now, send=send, app_url=app_url)
        counts["waiting" if outcome == PENDING else "sent"] += 1
    return counts


def let_back_in(db, data: object) -> dict:
    """[Dejar entrar de nuevo]: deletes `removed/{uid}`. Returns `{uid}`."""
    uid = (data if isinstance(data, dict) else {}).get("uid")
    if not isinstance(uid, str) or not uid or "/" in uid:
        raise safety.SafetyError("invalid-argument", "uid is required")
    reference = db.document(f"removed/{uid}")
    if not reference.get().exists:
        raise safety.SafetyError("not-found", "not out of Ronda")
    reference.delete()
    return {"uid": uid}
