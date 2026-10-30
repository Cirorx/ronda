"""Attendance: "¿Quién vino hoy?" (docs/PRODUCT.md § The weekly loop; #47).

On meeting day, an hour into the meeting, the host gets "¿Quién vino hoy?" and taps [Vino] /
[No vino] for each person. "Nadie más ve esta lista."

- `run_attendance_ask(db, now, send=...)`: the job (`jobs.JOBS["attendance_ask"]`). For each
  ronda that still meets, once its meeting today is an hour in (`ask_at`), it writes the
  host's roll and pushes the ask, once per ronda and week. The roll is created in a
  transaction before the push, which makes it once; it is held from 21:00 to 09:00 like every
  push and tried on the next run, but `ask_at` is never later than 20:00, so an evening ronda's
  ask still lands that evening. `force` (the admin's `run_job`) asks for the latest meeting
  whatever the day and hour, never past the gate.
- `record(db, uid, admin, data, now)`: the `record_attendance` callable's body, one tap.

Who is asked: the anfitrión, else the cola (the anfitrión paused, left or said "esta no" that
week), else nobody: the server holds no admin uid (the claim lives on the Auth token only), so
a ronda with no host shows its roll on the admin's `/admin/rondas`, and the admin records it.

Where things live (docs/ARCHITECTURE.md § Data model):
- `rondas/{id}/weeks/{isoWeek}.attendance {uid: bool}`: the record, read by the admin only
  (the numbers panel), never by a member.
- `rondas/{id}/rolls/{isoWeek}`: the host's roll, `get` by the ronda's anfitrión and cola and
  the admin: week, date, line, hour, people [{uid, firstName}] (the members in for that
  meeting), marks {uid: bool} (the host's copy of the record), askedUid, askedRole
  (anfitrion | cola | ""), askedAt, updatedAt.
"""

import logging
from collections.abc import Callable
from datetime import date, datetime, time, timedelta

import rsvp
import seguimos

log = logging.getLogger(__name__)

ASK_TYPE = "attendance"
"""`data.type` of the push; the phone draws it plain and a tap opens Mi ronda."""

ASK_AFTER = timedelta(hours=1)
"""How far into the meeting the host is asked."""

LATEST_ASK = time(rsvp.QUIET_FROM - 1)
"""The last hourly run before the quiet hours: an evening ronda is asked by then."""

RECORD_DAYS = 6
"""A meeting's attendance can be recorded or corrected until this many days after it."""

TITLE = "¿Quién vino hoy?"
BODY = "{line}. Marcá quién vino. Nadie más ve esta lista."

ANFITRION = "anfitrion"
COLA = "cola"


class AttendanceError(Exception):
    """A tap the callable refuses; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


# --- When ---------------------------------------------------------------------------------


def latest_meeting(db, ronda_id: str, ronda: dict, today: date) -> tuple[date, str]:
    """The ronda's latest meeting on or before `today`'s week and its ISO week: the last slot
    day on or before `today`, or the day a rain move postponed it to (`dateOverride`)."""
    slot_day = today - timedelta(days=(today.weekday() - rsvp.DAYS.index(ronda["slot"]["day"])) % 7)
    week = rsvp.iso_week(slot_day)
    snapshot = db.document(f"rondas/{ronda_id}/weeks/{week}").get()
    override = (snapshot.to_dict() or {}).get("dateOverride") if snapshot.exists else None
    try:
        return date.fromisoformat(override), week
    except (TypeError, ValueError):
        return slot_day, week


def ask_at(meeting: date, ronda: dict) -> datetime:
    """An hour into the meeting, and 20:00 at the latest; while the ronda has no hour, an hour
    before its band ends."""
    if hour := rsvp.meeting_hour(ronda):
        start = datetime.combine(meeting, time.fromisoformat(hour)) + ASK_AFTER
    else:
        end = rsvp.BANDS.get(ronda["slot"].get("time"), rsvp.BANDS["afternoon"])[1]
        start = datetime.combine(meeting, time(end)) - ASK_AFTER
    latest = datetime.combine(meeting, LATEST_ASK)
    return min(start, latest).replace(tzinfo=rsvp.MONTEVIDEO)


# --- Who ----------------------------------------------------------------------------------


def people(db, ronda_id: str, meeting: date, guests: dict[str, dict] | None = None) -> list[dict]:
    """The members in for `meeting`, by first name: everyone but those who left or are paused
    over it, and whoever took a freed seat from the bench (`guests`, rsvp.guests). Who said
    "esta no" stays on the list, so its order gives nobody away."""
    members = rsvp.counted(rsvp._members(db, ronda_id))
    uids = [uid for uid, member in members.items() if not rsvp._paused_on(member, meeting)]
    names = rsvp._first_names(db, uids)
    for uid, guest in (guests or {}).items():
        names.setdefault(uid, guest.get("firstName", ""))
    return [
        {"uid": uid, "firstName": names[uid]} for uid in sorted(names, key=lambda u: (names[u], u))
    ]


def asked(ronda: dict, in_list: set[str], answers: dict[str, str]) -> tuple[str, str]:
    """`(uid, role)` of the host to ask: the anfitrión, else the cola, each only while in for
    the meeting and not having said "esta no"; `("", "")` when neither can."""
    hosts = ronda.get("hosts") or {}
    for role in (ANFITRION, COLA):
        uid = hosts.get(role)
        if uid in in_list and answers.get(uid) != rsvp.NO:
            return uid, role
    return "", ""


# --- The ask ------------------------------------------------------------------------------


def messages(tokens, *, ronda_id: str, week: str, body: str, link: str) -> list[dict]:
    """One HTTP v1 message per `(token, platform)`, shaped like the RSVP push: data-only on
    Android, a notification that opens the roll on web, nothing for iPhones yet."""
    out = []
    for token, platform in tokens:
        if platform == "android":
            out.append(
                {
                    "token": token,
                    "data": {
                        "type": ASK_TYPE,
                        "rondaId": ronda_id,
                        "week": week,
                        "title": TITLE,
                        "body": body,
                    },
                    "android": {"priority": "HIGH"},
                }
            )
        elif platform == "web":
            out.append(
                {
                    "token": token,
                    "notification": {"title": TITLE, "body": body},
                    "webpush": {"fcm_options": {"link": link}},
                }
            )
    return out


def roll_link(app_url: str, ronda_id: str, week: str) -> str:
    """The host's screen on the web app, next to Mi ronda's URL."""
    return f"{app_url.rsplit('/', 1)[0]}/asistencia/{ronda_id}/{week}"


def _claim(roll_ref, roll: dict) -> Callable:
    def claim(transaction) -> bool:
        if roll_ref.get(transaction=transaction).exists:
            return False
        transaction.set(roll_ref, roll)
        return True

    return claim


def run_attendance_ask(
    db,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
    force: bool = False,
) -> dict:
    """The hourly attendance job; returns counts. `noHost` counts rolls written with nobody to
    ask, which the admin records from `/admin/rondas`."""
    counts = {"rondas": 0, "asked": 0, "noHost": 0, "messages": 0, "already": 0, "held": 0}
    today = rsvp.local(now).date()
    for snapshot in db.collection("rondas").stream():
        ronda = snapshot.to_dict()
        if ronda.get("status") not in rsvp.OPEN_STATUSES:
            continue
        counts["rondas"] += 1
        ronda_id = snapshot.id
        meeting, week = latest_meeting(db, ronda_id, ronda, today)
        if not force and (meeting != today or now < ask_at(meeting, ronda)):
            continue
        roll_ref = db.document(f"rondas/{ronda_id}/rolls/{week}")
        if roll_ref.get().exists:
            counts["already"] += 1
            continue
        if not rsvp.inside_gate(now):
            counts["held"] += 1
            continue
        week_snapshot = db.document(f"rondas/{ronda_id}/weeks/{week}").get()
        in_list = people(db, ronda_id, meeting, rsvp.guests(week_snapshot))
        uid, role = asked(ronda, {p["uid"] for p in in_list}, rsvp._rsvp(week_snapshot))
        line = rsvp.ronda_line(ronda)
        roll = {
            "week": week,
            "date": meeting.isoformat(),
            "line": line,
            "hour": rsvp.meeting_hour(ronda),
            "people": in_list,
            "marks": {},
            "askedUid": uid,
            "askedRole": role,
            "askedAt": now,
            "updatedAt": now,
        }
        if not rsvp._in_transaction(db, _claim(roll_ref, roll)):
            counts["already"] += 1
            continue
        if not uid:
            counts["noHost"] += 1
            continue
        outgoing = [
            (uid, message)
            for message in messages(
                rsvp._tokens(db, uid),
                ronda_id=ronda_id,
                week=week,
                body=BODY.format(line=line),
                link=roll_link(app_url, ronda_id, week),
            )
        ]
        try:
            counts["messages"] += seguimos.deliver(db, send, outgoing)
        except Exception:
            roll_ref.delete()
            raise
        counts["asked"] += 1
    log.info("attendance_ask: %s", counts)
    return counts


# --- The tap ------------------------------------------------------------------------------


def _path_part(data: dict, field: str) -> str:
    value = data.get(field)
    if not isinstance(value, str) or not value or "/" in value:
        raise AttendanceError("invalid-argument", f"{field} is required")
    return value


def record(db, caller: str, admin: bool, data: object, now: datetime) -> dict:
    """Records one tap, `{rondaId, week, uid, came}`, in the record and the host's roll in one
    transaction.

    Only the ronda's anfitrión or cola (while in the ronda), the host the roll was sent to, or
    the admin; only for someone on the roll; and only until `RECORD_DAYS` after the meeting.
    """
    data = data if isinstance(data, dict) else {}
    ronda_id, week = _path_part(data, "rondaId"), _path_part(data, "week")
    uid, came = _path_part(data, "uid"), data.get("came")
    if not isinstance(came, bool):
        raise AttendanceError("invalid-argument", "came is true or false")
    roll_ref = db.document(f"rondas/{ronda_id}/rolls/{week}")
    roll_snapshot = roll_ref.get()
    if not roll_snapshot.exists:
        raise AttendanceError("not-found", "no roll for that meeting")
    roll = roll_snapshot.to_dict()
    if not admin and not _hosts(db, ronda_id, roll, caller):
        raise AttendanceError("permission-denied", "only the ronda's hosts record it")
    if uid not in {person["uid"] for person in roll.get("people", [])}:
        raise AttendanceError("invalid-argument", "that person isn't on the roll")
    if rsvp.local(now).date() > date.fromisoformat(roll["date"]) + timedelta(days=RECORD_DAYS):
        raise AttendanceError("failed-precondition", "that meeting is too long ago")
    week_ref = db.document(f"rondas/{ronda_id}/weeks/{week}")

    def write(transaction) -> None:
        transaction.set(week_ref, {"attendance": {uid: came}}, merge=True)
        transaction.set(roll_ref, {"marks": {uid: came}, "updatedAt": now}, merge=True)

    rsvp._in_transaction(db, write)
    return {"week": week, "uid": uid, "came": came}


def _hosts(db, ronda_id: str, roll: dict, caller: str) -> bool:
    """Whether `caller` hosts this ronda now, or was the host asked for this roll."""
    if caller == roll.get("askedUid"):
        return True
    ronda = db.document(f"rondas/{ronda_id}").get().to_dict() or {}
    hosts = ronda.get("hosts") or {}
    if caller not in (hosts.get(ANFITRION), hosts.get(COLA)):
        return False
    member = db.document(f"rondas/{ronda_id}/members/{caller}").get()
    return member.exists and (member.to_dict() or {}).get("state") != "left"
