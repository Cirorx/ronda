"""Así va a ser: a newcomer's first visit, and who waits for them (docs/PRODUCT.md § First
visit; #70).

A newcomer is a member who joined a ronda that already had members within `NEWCOMER_DAYS`
(`newcomers`, which the weekly card's "someone new" block reads too). Before their first
meeting Mi ronda shows them "Así va a ser": "Te espera Jorge — tiene el termo verde.", the
place and its landmark, "Los primeros cinco minutos" and "¿Te querés ir antes? Decí «me tengo
que ir» y listo. Nadie se ofende." The phone shows it from two days before the meeting, or at
once when they join later.

The ronda's hosts (the anfitrión and the cola) are asked on their card who waits for them:
"Nico viene por primera vez el jueves. ¿Quién espera a Nico en frente al quiosco a las 15:50?"
[Espero yo] or another member, with how to be recognised. Until a host picks someone, whoever
opens that week waits: the phone reads that live from `rondas/{id}` (the week's `opener`, else
the anfitrión), so a handoff moves it too. A member the host picked can say "No puedo"; the
pick is cleared, the opener waits again, and the question goes back to the hosts, as "¿Abrís
vos?" goes back round (handoff.py, whose meeting and hour this reads). Nothing here sends a
message: the newcomer gets the card and the RSVP push they already get, nothing new.

The recognition line is the host's own words, shown to the newcomer, so it passes the
organiser's word gates (no emoji, voseo, no money, nothing that looks like a home or an
address), the hosts.py pattern; a refusal says which gate in the error's `details.reason`, and
the host's sheet says why.

- `run_first_visit(db, now)`: the job (`jobs.JOBS["first_visit"]`), hourly, sends nothing:
  writes the upcoming meeting's welcome for each newcomer without one. `welcome_ronda` is one
  ronda's, which "Sumar a esta ronda" (ronda_members.py) also runs, so a late joiner's card
  is there at once.
- `set_waiter(db, uid, data, now)`: the `set_welcome` callable's body, a host's pick.
- `decline(db, uid, data, now)`: the `decline_welcome` callable's body, the picked "No puedo".

`rondas/{id}/welcomes/{newcomerUid}` (docs/ARCHITECTURE.md § Data model): week, date, hour,
newcomerName, choices [{uid, firstName}] (who could wait: the members in for that meeting but
the newcomer), status (open | set), waiterUid?, waiterName?, sign?, setBy?, setByName?,
declined [uids], declinedName? (the last "No puedo"), createdAt, updatedAt. The newcomer reads
their own; the hosts read and list the ronda's; a picked waiter the one they were picked for.
No client writes it.
"""

from datetime import datetime, timedelta

import handoff
import rsvp
import safety
from organiser import gates

NEWCOMER_DAYS = 7
"""A member who joined within this many days is new to the ronda."""

OPEN, SET = "open", "set"

SIGN_LIMIT = 60
"""How long the recognition line ("tiene el termo verde") may be."""

HOST_ROLES = ("anfitrion", "cola")


class WelcomeError(Exception):
    """A call the callables refuse: `code` is the callable's error code and `reason`, when the
    recognition line was held, the gate that held it (emoji, voseo, money, public_place)."""

    def __init__(self, code: str, message: str, reason: str | None = None) -> None:
        super().__init__(message)
        self.code = code
        self.reason = reason


# --- Who is new ---------------------------------------------------------------------------


def newcomers(members: dict[str, dict], now: datetime) -> list[str]:
    """The active members who joined within `NEWCOMER_DAYS` of `now`, earliest first; none
    while everyone is new, as in a ronda that just started."""
    since = now - timedelta(days=NEWCOMER_DAYS)
    new = [
        uid
        for uid, m in members.items()
        if m.get("state", "active") == "active"
        and isinstance(m.get("joinedAt"), datetime)
        and m["joinedAt"] >= since
    ]
    if len(rsvp.counted(members)) <= len(new):
        return []
    return sorted(new, key=lambda u: (members[u]["joinedAt"], u))


# --- The welcome --------------------------------------------------------------------------


def _choices(db, members: dict, answers: dict, day, newcomer: str) -> list[dict]:
    """Who could wait: the members in for the meeting on `day`, but the newcomer and anyone
    the admin separated from them ([Separarlos], safety.py)."""
    apart = safety.apart_from(db, [newcomer])
    uids = [
        uid
        for uid, member in members.items()
        if uid != newcomer
        and uid not in apart
        and not rsvp._paused_on(member, day)
        and answers.get(uid) != rsvp.NO
    ]
    names = rsvp._first_names(db, uids)
    return [
        {"uid": uid, "firstName": names[uid]} for uid in sorted(uids, key=lambda u: (names[u], u))
    ]


def _meeting(db, ronda_id: str, ronda: dict, now: datetime):
    """The upcoming meeting's date, ISO week, start and RSVP answers."""
    day, week = handoff.meeting_of(db, ronda_id, ronda, rsvp.local(now).date())
    snapshot = db.document(f"rondas/{ronda_id}/weeks/{week}").get()
    answers = rsvp._rsvp(snapshot)
    return day, week, handoff.starts_at(day, ronda), answers


def welcome_ronda(db, ronda_id: str, ronda: dict, now: datetime) -> int:
    """Writes the upcoming meeting's welcome for each of ronda `ronda_id`'s newcomers who has
    none yet and is in for it, and keeps that meeting's welcomes' `choices` current as the
    answers come in; returns how many it wrote. A newcomer gets one first visit."""
    day, week, start, answers = _meeting(db, ronda_id, ronda, now)
    if now >= start:
        return 0
    members = rsvp.counted(rsvp._members(db, ronda_id))
    written = 0
    for uid in newcomers(members, now):
        ref = db.document(f"rondas/{ronda_id}/welcomes/{uid}")
        if ref.get().exists or rsvp._paused_on(members[uid], day) or answers.get(uid) == rsvp.NO:
            continue
        ref.set(
            {
                "week": week,
                "date": day.isoformat(),
                "hour": rsvp.meeting_hour(ronda),
                "newcomerName": rsvp._first_names(db, [uid])[uid],
                "choices": _choices(db, members, answers, day, uid),
                "status": OPEN,
                "declined": [],
                "createdAt": now,
                "updatedAt": now,
            }
        )
        written += 1
    # Who could wait changes as the week's answers come in: keep the hosts' list current, and
    # drop a pick who can't wait any more (left, said "esta no", separated from the newcomer).
    for snapshot in db.collection(f"rondas/{ronda_id}/welcomes").stream():
        welcome = snapshot.to_dict() or {}
        if welcome.get("week") != week:
            continue
        choices = _choices(db, members, answers, day, snapshot.id)
        update: dict = {"choices": choices} if choices != welcome.get("choices") else {}
        if welcome.get("status") == SET and welcome.get("waiterUid") not in {
            choice["uid"] for choice in choices
        }:
            update |= _no_pick()
        if update:
            db.document(f"rondas/{ronda_id}/welcomes/{snapshot.id}").update(
                {**update, "updatedAt": now}
            )
    return written


def _no_pick() -> dict:
    """The fields that clear a host's pick: whoever opens waits again."""
    from google.cloud.firestore import DELETE_FIELD

    return {
        "status": OPEN,
        "waiterUid": DELETE_FIELD,
        "waiterName": DELETE_FIELD,
        "sign": DELETE_FIELD,
        "setBy": DELETE_FIELD,
        "setByName": DELETE_FIELD,
    }


def run_first_visit(db, now: datetime) -> dict:
    """The hourly job: every ronda that still meets gets its newcomers' welcomes. Sends
    nothing, so it runs at any hour."""
    counts = {"rondas": 0, "welcomes": 0}
    for snapshot in db.collection("rondas").stream():
        ronda = snapshot.to_dict()
        if ronda.get("status") not in rsvp.OPEN_STATUSES:
            continue
        counts["rondas"] += 1
        counts["welcomes"] += welcome_ronda(db, snapshot.id, ronda, now)
    return counts


# --- The host's pick and the waiter's "No puedo" ------------------------------------------


def _path_part(data: dict, field: str) -> str:
    value = data.get(field)
    if not isinstance(value, str) or not value or "/" in value:
        raise WelcomeError("invalid-argument", f"{field} is required")
    return value


def _sign(value: object) -> str:
    if value is None:
        value = ""
    if not isinstance(value, str):
        raise WelcomeError("invalid-argument", "sign is a string")
    value = " ".join(value.split())
    if len(value) > SIGN_LIMIT:
        raise WelcomeError("invalid-argument", f"sign is at most {SIGN_LIMIT} characters")
    if value and not (verdict := gates.check_words(value)).allowed:
        raise WelcomeError("failed-precondition", f"sign: {verdict.reason}", verdict.gate)
    return value


def _upcoming(db, data: dict, now: datetime):
    """The ronda, its welcome for `newcomerUid` and that welcome's reference, while it is for
    the upcoming meeting and that meeting hasn't started."""
    ronda_id, newcomer = _path_part(data, "rondaId"), _path_part(data, "newcomerUid")
    snapshot = db.document(f"rondas/{ronda_id}").get()
    if not snapshot.exists:
        raise WelcomeError("not-found", "no such ronda")
    ronda = snapshot.to_dict()
    ref = db.document(f"rondas/{ronda_id}/welcomes/{newcomer}")
    welcome_snapshot = ref.get()
    if not welcome_snapshot.exists:
        raise WelcomeError("not-found", "no welcome for that member")
    welcome = welcome_snapshot.to_dict() or {}
    day, week, start, answers = _meeting(db, ronda_id, ronda, now)
    if welcome.get("week") != week or now >= start:
        raise WelcomeError("failed-precondition", "that meeting has started")
    return ronda_id, ronda, newcomer, ref, welcome, day, answers


def set_waiter(db, uid: str, data: object, now: datetime) -> dict:
    """A host picks who waits for a newcomer, `{rondaId, newcomerUid, waiterUid, sign?}`: the
    anfitrión or the cola, until the meeting starts. The waiter is a member in for it, never
    the newcomer; the sign passes the word gates. Each call replaces the pick. Returns `{status,
    waiterUid}`."""
    from google.cloud.firestore import DELETE_FIELD

    data = data if isinstance(data, dict) else {}
    ronda_id, ronda, newcomer, ref, welcome, day, answers = _upcoming(db, data, now)
    hosts = ronda.get("hosts") or {}
    if uid not in [hosts.get(role) for role in HOST_ROLES]:
        raise WelcomeError("permission-denied", "only the ronda's hosts choose who waits")
    members = rsvp.counted(rsvp._members(db, ronda_id))
    choices = _choices(db, members, answers, day, newcomer)
    waiter = data.get("waiterUid")
    if waiter not in {choice["uid"] for choice in choices}:
        raise WelcomeError("invalid-argument", "waiterUid is a member in for the meeting")
    sign = _sign(data.get("sign"))
    names = rsvp._first_names(db, {uid, waiter})
    ref.update(
        {
            "status": SET,
            "waiterUid": waiter,
            "waiterName": names[waiter],
            "sign": sign or DELETE_FIELD,
            "setBy": uid,
            "setByName": names[uid],
            "choices": choices,
            "declined": [u for u in welcome.get("declined", []) if u != waiter],
            "declinedName": DELETE_FIELD,
            "updatedAt": now,
        }
    )
    return {"status": SET, "waiterUid": waiter}


def decline(db, uid: str, data: object, now: datetime) -> dict:
    """The member a host picked says "No puedo", `{rondaId, newcomerUid}`: the pick and its
    sign are cleared, whoever opens waits again, and the hosts see who couldn't. Returns
    `{status}`."""
    data = data if isinstance(data, dict) else {}
    ronda_id, _, newcomer, ref, welcome, day, answers = _upcoming(db, data, now)
    if welcome.get("status") != SET or welcome.get("waiterUid") != uid:
        raise WelcomeError("permission-denied", "you weren't picked to wait")
    members = rsvp.counted(rsvp._members(db, ronda_id))
    ref.update(
        {
            **_no_pick(),
            "choices": _choices(db, members, answers, day, newcomer),
            "declined": [*welcome.get("declined", []), uid],
            "declinedName": welcome.get("waiterName", ""),
            "updatedAt": now,
        }
    )
    return {"status": OPEN}
