"""¿Abrís vos?: when the anfitrión can't open a meeting, someone else is asked to (docs/PRODUCT.md
§ The weekly loop, "Hosts"; #47).

"Mirta no puede hoy. ¿Abrís vos?" — "Abrir es llegar diez minutos antes, a las 15:50, y saludar
a los que van llegando. Nada más." [Sí, abro yo] [Hoy no puedo]; a no passes the question on.
A plain code job: fixed rules choose who is asked and when, never the model. Its messages pass
the organiser's gates and land in the trace like the agent's.

- `run_handoff(db, now, send=...)`: the job (`jobs.JOBS["handoff"]`), hourly; `step_ronda` is
  one ronda's step, which the answer callable also takes after a no.
- `answer(db, uid, data, now, send=...)`: the `answer_handoff` callable's body.

When, for the upcoming meeting, once its RSVP push went out and until it starts:
- the anfitrión said "esta no", is paused over the meeting or left the ronda: the next hourly
  run inside the gate;
- the anfitrión hasn't answered by noon the day before (`UNANSWERED_BY`).
The anfitrión's "voy" before anyone takes over ends it (`back`). Nothing is asked from 21:00
to 09:00: a deadline that passes at night moves on at 09:00. The job reads the answers from
`weeks/{w}.rsvp`, so it learns of an "esta no" within the hour.

Who: the cola alone, for `COLA_HOURS`; then, at once, every other member in for the meeting
who hasn't said "esta no", until the meeting starts. The first "Sí, abro yo" opens it, says
"voy" for them, and closes every other question. With nobody, the admin sees "Nadie confirmó
que abre" on `/admin/rondas` (the server holds no admin uid to push to).

Where things live (docs/ARCHITECTURE.md § Data model):
- `rondas/{id}/handoffs/{isoWeek}`, read by no client: week, date, hour, fromUid, fromName,
  reason (no | away | unanswered), step (cola | members | taken | nobody | back), asked [uids],
  declined [uids], askedAt, deadline, takenBy?, takenName?, takenAt?, updatedAt.
- `rondas/{id}/handoff_asks/{uid}`: the member's own question, read by that member only:
  week, date, hour, fromName and reason (the cola's only; "" when the others are asked), status
  (open | taken | closed), answer?, answeredAt?, askedAt.
- `rondas/{id}.opener {week, uid, firstName}`: who opens that week, for the card ("Esta semana
  abre Ana"), the después and the attendance ask.
The acta says who was asked and who opens, never why the anfitrión can't.
"""

import contextlib
from collections.abc import Callable
from datetime import date, datetime, time, timedelta

import rsvp
from organiser import gates, moves, outbox
from organiser.trace import HOST, Trace

JOB = "handoff"

NO, AWAY, UNANSWERED = "no", "away", "unanswered"
COLA, MEMBERS, TAKEN, NOBODY, BACK = "cola", "members", "taken", "nobody", "back"
ASKING = (COLA, MEMBERS)

OPEN, CLOSED = "open", "closed"

COLA_HOURS = 2
"""How long the cola has before the others are asked."""

UNANSWERED_BY = time(12)
"""An anfitrión with no answer by noon the day before the meeting counts as not opening."""

EARLY = timedelta(minutes=10)
"""Opening is arriving this much before the meeting."""

ASK_TYPE = "handoff"
"""`data.type` of the question; a tap opens Mi ronda, whose card asks it."""


class HandoffError(Exception):
    """An answer the callable refuses; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


# --- When ---------------------------------------------------------------------------------


def meeting_of(db, ronda_id: str, ronda: dict, today: date) -> tuple[date, str]:
    """The upcoming meeting's date and ISO week: the slot's next day, or the day a rain move
    postponed it to."""
    slot_day = rsvp.next_meeting(ronda["slot"]["day"], today)
    week = rsvp.iso_week(slot_day)
    snapshot = db.document(f"rondas/{ronda_id}/weeks/{week}").get()
    override = (snapshot.to_dict() or {}).get("dateOverride")
    try:
        return date.fromisoformat(override), week
    except (TypeError, ValueError):
        return slot_day, week


def starts_at(day: date, ronda: dict) -> datetime:
    """When the meeting starts: its hour, or the start of its band while it has none."""
    if hour := rsvp.meeting_hour(ronda):
        start = time.fromisoformat(hour)
    else:
        start = time(rsvp.BANDS.get(ronda["slot"].get("time"), rsvp.BANDS["afternoon"])[0])
    return datetime.combine(day, start, tzinfo=rsvp.MONTEVIDEO)


def reason(ronda: dict, members: dict, answers: dict, day: date, now: datetime) -> str | None:
    """Why the anfitrión won't open the meeting on `day`, or `None` while they will."""
    uid = (ronda.get("hosts") or {}).get("anfitrion")
    member = members.get(uid)
    if member is None or rsvp._paused_on(member, day):
        return AWAY
    if answers.get(uid) == rsvp.NO:
        return NO
    if answers.get(uid) == rsvp.YES:
        return None
    by = datetime.combine(day - timedelta(days=1), UNANSWERED_BY, tzinfo=rsvp.MONTEVIDEO)
    return UNANSWERED if now >= by else None


# --- The words ----------------------------------------------------------------------------


def spoken_day(day: date, today: date) -> str:
    """ "hoy", "mañana" or "el jueves"."""
    if day == today:
        return "hoy"
    if day == today + timedelta(days=1):
        return "mañana"
    return f"el {moves.weekday(day)}"


def opening_words(hour: str | None) -> str:
    """ "Abrir es llegar diez minutos antes, a las 15:50, …": the time only when the ronda has
    an hour."""
    if hour:
        early = datetime.combine(date.min, time.fromisoformat(hour)) - EARLY
        when = f", a las {early:%H:%M},"
    else:
        when = ""
    return f"Abrir es llegar diez minutos antes{when} y saludar a los que van llegando. Nada más."


def ask_text(state: dict, step: str, today: date) -> str:
    """The question: to the cola it names the anfitrión, to the others nobody."""
    when = spoken_day(date.fromisoformat(state["date"]), today)
    if step == COLA and state["reason"] == UNANSWERED:
        lead = f"{state['fromName']} no confirmó que viene {when}."
    elif step == COLA:
        lead = f"{state['fromName']} no puede {when}."
    else:
        lead = f"Todavía nadie abre {when}."
    return f"{lead} ¿Abrís vos? {opening_words(state.get('hour'))}"


# --- The step -----------------------------------------------------------------------------


def _in(members: dict, answers: dict, day: date, uid: str | None) -> bool:
    member = members.get(uid)
    return member is not None and not rsvp._paused_on(member, day) and answers.get(uid) != rsvp.NO


def _close_asks(db, ronda_id: str, uids, *, status: str = CLOSED) -> None:
    for uid in uids:
        ref = db.document(f"rondas/{ronda_id}/handoff_asks/{uid}")
        if (ref.get().to_dict() or {}).get("status") == OPEN:
            ref.update({"status": status})


def _trace(db, ronda_id: str, week: str, now: datetime, force: bool) -> Trace:
    trace = Trace(db, f"{ronda_id}_{week}_{JOB}", ronda_id=ronda_id, week=week, now=now)
    trace.start(job=JOB, model="", forced=force)
    return trace


def _ask(db, ronda_id, ronda, state, step, uids, names, now, send, app_url, trace) -> None:
    """Writes each asked member's own question and sends it through the gates."""
    today = rsvp.local(now).date()
    for uid in uids:
        db.document(f"rondas/{ronda_id}/handoff_asks/{uid}").set(
            {
                "week": state["week"],
                "date": state["date"],
                "hour": state.get("hour"),
                "fromName": state["fromName"] if step == COLA else "",
                "reason": state["reason"] if step == COLA else "",
                "status": OPEN,
                "askedAt": now,
            }
        )
        draft = outbox.prepare(
            db,
            outbox.Recipient(uid, names[uid]),
            title=rsvp.ronda_line(ronda),
            text=ask_text(state, step, today),
            kind=gates.ASK,
            week=state["week"],
            now=now,
        )
        outbox.deliver(
            db,
            trace,
            draft,
            send=send,
            data={"type": ASK_TYPE, "rondaId": ronda_id, "week": state["week"]},
            link=app_url,
            now=now,
        )
    day = moves.weekday(date.fromisoformat(state["date"]))
    if step == COLA:
        trace.acta(JOB, f"Le preguntó a {names[uids[0]]} si abre el {day}.")
    else:
        trace.acta(JOB, f"Les preguntó a {len(uids)} del grupo si alguien abre el {day}.")


def _advance(db, ronda_id, ronda, state, members, answers, now, send, app_url, force) -> str:
    """Moves the handoff on from where `state` is: the cola, then the others, then nobody.
    Returns the step it reached."""
    day = date.fromisoformat(state["date"])
    start = starts_at(day, ronda)
    asked = list(state.get("asked", []))
    trace = _trace(db, ronda_id, state["week"], now, force)
    cola = (ronda.get("hosts") or {}).get("cola")
    if state.get("step") is None and cola != state["fromUid"] and _in(members, answers, day, cola):
        step, uids, deadline = COLA, [cola], min(now + timedelta(hours=COLA_HOURS), start)
    else:
        _close_asks(db, ronda_id, asked)
        uids = sorted(
            uid
            for uid in members
            if uid != state["fromUid"] and uid not in asked and _in(members, answers, day, uid)
        )
        more = uids and state.get("step") != MEMBERS
        step, deadline = (MEMBERS, start) if more else (NOBODY, None)
    ref = db.document(f"rondas/{ronda_id}/handoffs/{state['week']}")
    if step == NOBODY:
        ref.update({"step": NOBODY, "updatedAt": now})
        trace.acta(JOB, f"Nadie confirmó que abre el {moves.weekday(day)}.")
        trace.finish("done")
        return NOBODY
    names = rsvp._first_names(db, uids)
    ref.update(
        {
            "step": step,
            "asked": asked + uids,
            "askedAt": now,
            "deadline": deadline,
            "updatedAt": now,
        }
    )
    _ask(db, ronda_id, ronda, state, step, uids, names, now, send, app_url, trace)
    trace.finish("done")
    return step


def _claim(ref, state: dict) -> Callable:
    def claim(transaction) -> bool:
        if ref.get(transaction=transaction).exists:
            return False
        transaction.set(ref, state)
        return True

    return claim


def step_ronda(
    db, ronda_id: str, ronda: dict, now: datetime, *, send, app_url: str, force: bool
) -> str:
    """One ronda's handoff at `now`: starts it, moves it on, or ends it. Returns what happened:
    `idle`, `waiting`, `held`, `back`, `late`, `already` or the step it reached."""
    today = rsvp.local(now).date()
    day, week = meeting_of(db, ronda_id, ronda, today)
    week_snapshot = db.document(f"rondas/{ronda_id}/weeks/{week}").get()
    week_doc = (week_snapshot.to_dict() or {}) if week_snapshot.exists else {}
    ref = db.document(f"rondas/{ronda_id}/handoffs/{week}")
    snapshot = ref.get()
    state = (snapshot.to_dict() or {}) if snapshot.exists else None
    if state is not None and state.get("step") not in ASKING:
        return "idle"
    if now >= starts_at(day, ronda):
        if state is None:
            return "idle"
        _close_asks(db, ronda_id, state.get("asked", []))
        ref.update({"step": NOBODY, "updatedAt": now})
        return "late"
    if not force and not week_doc.get("rsvpSentAt"):
        return "idle"
    members = rsvp.counted(rsvp._members(db, ronda_id))
    answers = dict(week_doc.get("rsvp", {}))
    why = reason(ronda, members, answers, day, now)
    if why is None:
        if state is None:
            return "idle"
        _close_asks(db, ronda_id, state.get("asked", []))
        ref.update({"step": BACK, "updatedAt": now})
        return BACK
    if state is not None:
        declined = set(state.get("declined", []))
        waiting = now < state["deadline"] and not set(state.get("asked", [])) <= declined
        if waiting:
            return "waiting"
    if not rsvp.inside_gate(now):
        return "held"
    if state is None:
        from_uid = ronda["hosts"]["anfitrion"]
        state = {
            "week": week,
            "date": day.isoformat(),
            "hour": rsvp.meeting_hour(ronda),
            "fromUid": from_uid,
            "fromName": rsvp._first_names(db, [from_uid])[from_uid],
            "reason": why,
            "step": None,
            "asked": [],
            "declined": [],
            "createdAt": now,
        }
        if not rsvp._in_transaction(db, _claim(ref, state)):
            return "already"
    return _advance(db, ronda_id, ronda, state, members, answers, now, send, app_url, force)


def run_handoff(
    db,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
    force: bool = False,
) -> dict:
    """The hourly handoff job; returns how many rondas reached each outcome. `force` (the
    admin's `run_job`) skips waiting for the RSVP push, never the gate."""
    counts: dict[str, int] = {"rondas": 0}
    for snapshot in db.collection("rondas").stream():
        ronda = snapshot.to_dict()
        if ronda.get("status") not in rsvp.OPEN_STATUSES:
            continue
        if not (ronda.get("hosts") or {}).get("anfitrion"):
            continue
        counts["rondas"] += 1
        outcome = step_ronda(db, snapshot.id, ronda, now, send=send, app_url=app_url, force=force)
        counts[outcome] = counts.get(outcome, 0) + 1
    return counts


# --- The answer ---------------------------------------------------------------------------


def _path_part(data: dict, field: str) -> str:
    value = data.get(field)
    if not isinstance(value, str) or not value or "/" in value:
        raise HandoffError("invalid-argument", f"{field} is required")
    return value


def answer(
    db,
    uid: str,
    data: object,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
) -> dict:
    """Records "Sí, abro yo" or "Hoy no puedo", `{rondaId, week, answer: yes | no}`, from a
    member asked and not answered yet. A yes, the first one, opens the meeting; a no moves the
    question on once everyone asked said no. Returns `{status: taken | declined}`."""
    data = data if isinstance(data, dict) else {}
    ronda_id, week = _path_part(data, "rondaId"), _path_part(data, "week")
    value = data.get("answer")
    if value not in rsvp.ANSWERS:
        raise HandoffError("invalid-argument", "answer is yes or no")
    own_ref = db.document(f"rondas/{ronda_id}/handoff_asks/{uid}")
    own_snapshot = own_ref.get()
    own = (own_snapshot.to_dict() or {}) if own_snapshot.exists else {}
    if own.get("week") != week:
        raise HandoffError("permission-denied", "you weren't asked")
    if own.get("status") != OPEN:
        raise HandoffError("failed-precondition", "the question is closed")
    ref = db.document(f"rondas/{ronda_id}/handoffs/{week}")
    ronda_ref = db.document(f"rondas/{ronda_id}")
    name = rsvp._first_names(db, [uid])[uid]

    if value == rsvp.NO:
        state = ref.get().to_dict() or {}
        own_ref.update({"status": CLOSED, "answer": rsvp.NO, "answeredAt": now})
        ref.update({"declined": [*state.get("declined", []), uid], "updatedAt": now})
        ronda = ronda_ref.get().to_dict() or {}
        step_ronda(db, ronda_id, ronda, now, send=send, app_url=app_url, force=False)
        return {"status": "declined"}

    def take(transaction) -> dict | None:
        state = ref.get(transaction=transaction).to_dict() or {}
        if state.get("step") not in ASKING:
            return None
        transaction.update(ref, {"step": TAKEN, "takenBy": uid, "takenName": name, "takenAt": now})
        transaction.update(ronda_ref, {"opener": {"week": week, "uid": uid, "firstName": name}})
        transaction.update(own_ref, {"status": TAKEN, "answer": rsvp.YES, "answeredAt": now})
        return state

    state = rsvp._in_transaction(db, take)
    if state is None:
        own_ref.update({"status": CLOSED})
        raise HandoffError("failed-precondition", "someone else opens")
    _close_asks(db, ronda_id, [u for u in state.get("asked", []) if u != uid])
    trace = _trace(db, ronda_id, week, now, False)
    day = moves.weekday(date.fromisoformat(state["date"]))
    trace.acta(JOB, f"{name} abre el {day}.", HOST)
    trace.finish("done")
    week_doc = db.document(f"rondas/{ronda_id}/weeks/{week}").get().to_dict() or {}
    if week_doc.get("rsvp", {}).get(uid) != rsvp.YES:
        with contextlib.suppress(rsvp.RsvpError):
            rsvp.answer(db, uid, ronda_id, rsvp.YES, now, week=week)
    return {"status": TAKEN}
