"""The buddy: the person a member chose to hear when they miss a week without saying so
(docs/PRODUCT.md § The weekly loop, "Buddy"; the `prompt_buddy` part of #50, the rule from #9).

"Si un día faltás sin avisar, ¿a quién le avisamos? Elegí a alguien que ya tenga tu WhatsApp."
— "Nadie más se entera, y no avisamos a tu familia." It is chosen after the member's first
meeting, never at sign-up, from the other members of their ronda, by first name. Ronda never
asks for, stores or sends a phone number: [Le escribo] opens WhatsApp with no number and no
text, and the buddy opens the chat they already have.

A plain code job, not the model. The message passes the organiser's gates and lands in the
admin's trace; it is never in the acta, which the whole ronda reads.

- `options(db, uid, data, now)`: the `buddy_options` callable's body: whether it is time to
  choose, who could be chosen and who is.
- `choose(db, uid, data)`: the `set_buddy` callable's body; `""` chooses nobody ("Ahora no").
- `run_prompt_buddy(db, now, send=...)`: the job (`jobs.JOBS["prompt_buddy"]`): on Fridays,
  for each member marked [No vino] at a meeting in the past week who hadn't said "esta no" and
  wasn't paused, once, only their buddy gets "Graciela no vino el jueves. Te eligió a vos para
  estas cosas. ¿Le escribís? Graciela no sabe que te avisamos." No escalation, no family.

Where things live (docs/ARCHITECTURE.md § Data model):
- `users/{uid}.buddyUid`: who they chose (`""` for nobody); the owner's own document.
- `rondas/{id}/buddy_asks/{uid}`: what the buddy's card shows, read by that buddy only: status
  (open | closed), asks [{firstName, day, week, at}], updatedAt; the buddy closes it from the
  card ([Le escribo] or [Ahora no]).
- `rondas/{id}/buddy_prompts/{isoWeek}`: prompted {uid: at}, which makes it once; no client
  reads it.
"""

from collections.abc import Callable
from datetime import date, datetime, timedelta

import rsvp
from organiser import gates, moves, outbox
from organiser.trace import Trace

JOB = "prompt_buddy"

FRIDAY = 4
"""`date.weekday()` of the day the prompt goes out."""
PROMPT_FROM = 10
"""The hour on Friday it starts; the gate holds it after 21:00, and the next Friday is too
late, so a Friday missed entirely sends nothing."""

LOOKBACK_DAYS = 7
"""A meeting in the seven days before the Friday counts."""

ASK_TYPE = "buddy"
"""`data.type` of the message; a tap opens Mi ronda, whose card has [Le escribo]."""

OPEN, CLOSED = "open", "closed"


class BuddyError(Exception):
    """A request the callables refuse; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def _ronda_id(data: object) -> str:
    ronda_id = (data if isinstance(data, dict) else {}).get("rondaId")
    if not isinstance(ronda_id, str) or not ronda_id or "/" in ronda_id:
        raise BuddyError("invalid-argument", "rondaId is required")
    return ronda_id


def _member_of(db, uid: str, ronda_id: str) -> dict[str, dict]:
    members = rsvp.counted(rsvp._members(db, ronda_id))
    if uid not in members:
        raise BuddyError("permission-denied", "not a member of this ronda")
    return members


def _joined(member: dict) -> date:
    joined = member.get("joinedAt")
    return rsvp.local(joined).date() if isinstance(joined, datetime) else date.min


def _meeting_day(week: dict) -> date | None:
    for field in ("dateOverride", "date"):
        try:
            return date.fromisoformat(week[field])
        except (KeyError, TypeError, ValueError):
            continue
    return None


def options(db, uid: str, data: object, now: datetime) -> dict:
    """`{due, chosen, buddyUid, buddyName, choices}` for the caller in ronda `rondaId`: `due`
    once a meeting of the ronda has passed since they joined; `chosen` once they picked someone
    or nobody; the buddy only while still in the ronda; `choices` the other members by first
    name."""
    ronda_id = _ronda_id(data)
    members = _member_of(db, uid, ronda_id)
    today = rsvp.local(now).date()
    joined = _joined(members[uid])
    due = any(
        joined <= day < today
        for snapshot in db.collection(f"rondas/{ronda_id}/weeks").stream()
        if (day := _meeting_day(snapshot.to_dict() or {})) is not None
    )
    others = [other for other in members if other != uid]
    names = rsvp._first_names(db, others)
    choices = [
        {"uid": other, "firstName": names[other]}
        for other in sorted(others, key=lambda u: (names[u], u))
    ]
    user = db.document(f"users/{uid}").get().to_dict() or {}
    chosen = user.get("buddyUid")
    buddy = chosen if chosen in names else ""
    return {
        "due": due,
        "chosen": isinstance(chosen, str),
        "buddyUid": buddy,
        "buddyName": names.get(buddy, ""),
        "choices": choices,
    }


def choose(db, uid: str, data: object) -> dict:
    """Saves the caller's buddy, `{rondaId, buddyUid}`: another member of that ronda, or `""`
    for nobody. Returns `{buddyUid, buddyName}`."""
    ronda_id = _ronda_id(data)
    members = _member_of(db, uid, ronda_id)
    buddy = data.get("buddyUid")
    if not isinstance(buddy, str) or (buddy and (buddy == uid or buddy not in members)):
        raise BuddyError("invalid-argument", "buddyUid is another member of the ronda, or ''")
    db.document(f"users/{uid}").set({"buddyUid": buddy}, merge=True)
    name = rsvp._first_names(db, [buddy])[buddy] if buddy else ""
    return {"buddyUid": buddy, "buddyName": name}


# --- The Friday prompt --------------------------------------------------------------------


def prompt_text(name: str, day: date) -> tuple[str, str]:
    """The title and the text: the missing member's first name, and nothing else of theirs."""
    title = f"{name} no vino el {moves.weekday(day)}"
    return title, (
        f"{title}. Te eligió a vos para estas cosas. ¿Le escribís? {name} no sabe que te avisamos."
    )


def _claim(ref, uid: str, now: datetime) -> Callable:
    def claim(transaction) -> bool:
        snapshot = ref.get(transaction=transaction)
        prompted = (snapshot.to_dict() or {}).get("prompted", {}) if snapshot.exists else {}
        if uid in prompted:
            return False
        transaction.set(ref, {"prompted": {uid: now}}, merge=True)
        return True

    return claim


def _add_ask(db, ronda_id: str, buddy: str, entry: dict, now: datetime) -> None:
    ref = db.document(f"rondas/{ronda_id}/buddy_asks/{buddy}")

    def add(transaction) -> None:
        snapshot = ref.get(transaction=transaction)
        current = (snapshot.to_dict() or {}) if snapshot.exists else {}
        asks = current.get("asks", []) if current.get("status") == OPEN else []
        transaction.set(ref, {"status": OPEN, "asks": [*asks, entry], "updatedAt": now})

    rsvp._in_transaction(db, add)


def missed(week: dict, members: dict[str, dict], day: date) -> list[str]:
    """Who was marked [No vino] without having said "esta no" and without a pause over `day`."""
    answers = week.get("rsvp", {})
    return sorted(
        uid
        for uid, came in (week.get("attendance") or {}).items()
        if came is False
        and answers.get(uid) != rsvp.NO
        and uid in members
        and not rsvp._paused_on(members[uid], day)
    )


def run_prompt_buddy(
    db,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
    force: bool = False,
) -> dict:
    """The Friday job; returns counts. `force` (the admin's `run_job`) skips the day and hour,
    never the gate or the once-per-miss mark."""
    counts = {"prompted": 0, "noBuddy": 0, "already": 0, "held": 0}
    here = rsvp.local(now)
    if not force and (here.weekday() != FRIDAY or here.hour < PROMPT_FROM):
        return counts
    today = here.date()
    for snapshot in db.collection("rondas").stream():
        if (snapshot.to_dict() or {}).get("status") not in rsvp.OPEN_STATUSES:
            continue
        ronda_id = snapshot.id
        members = rsvp.counted(rsvp._members(db, ronda_id))
        for week_snapshot in db.collection(f"rondas/{ronda_id}/weeks").stream():
            week = week_snapshot.to_dict() or {}
            day = _meeting_day(week)
            if day is None or not today - timedelta(days=LOOKBACK_DAYS) <= day < today:
                continue
            for uid in missed(week, members, day):
                user = db.document(f"users/{uid}").get().to_dict() or {}
                buddy = user.get("buddyUid")
                if buddy not in members or buddy == uid:
                    counts["noBuddy"] += 1
                    continue
                if not rsvp.inside_gate(now):
                    counts["held"] += 1
                    continue
                ref = db.document(f"rondas/{ronda_id}/buddy_prompts/{week_snapshot.id}")
                if not rsvp._in_transaction(db, _claim(ref, uid, now)):
                    counts["already"] += 1
                    continue
                _prompt(db, ronda_id, week_snapshot.id, uid, buddy, day, now, send, app_url)
                counts["prompted"] += 1
    return counts


def _prompt(db, ronda_id, week, uid, buddy, day, now, send, app_url) -> None:
    names = rsvp._first_names(db, [uid, buddy])
    title, text = prompt_text(names[uid], day)
    _add_ask(
        db,
        ronda_id,
        buddy,
        {"firstName": names[uid], "day": rsvp.DAYS[day.weekday()], "week": week, "at": now},
        now,
    )
    trace = Trace(db, f"{ronda_id}_{week}_buddy", ronda_id=ronda_id, week=week, now=now)
    trace.start(job=JOB, model="", forced=False)
    draft = outbox.prepare(
        db,
        outbox.Recipient(buddy, names[buddy]),
        title=title,
        text=text,
        kind=gates.ASK,
        week=week,
        now=now,
    )
    outbox.deliver(
        db,
        trace,
        draft,
        send=send,
        data={"type": ASK_TYPE, "rondaId": ronda_id},
        link=app_url,
        now=now,
    )
    trace.finish("done")
