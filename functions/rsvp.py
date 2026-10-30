"""The weekly RSVP: the "¿Venís?" push, the answers and the "who's coming" view members read.

`run_rsvp_push(db, now, send=...)` is the job the hourly dispatcher and the admin's `run_job`
call: once a week per ronda, at the ronda's lead time (`rsvpLead`, default two days before at
19:00 in Montevideo), it sends every member still in the ronda the push. `answer(db, uid, ...)`
is the `answer_rsvp` callable's body: it records one member's "voy" or "esta no".

Where things live (docs/ARCHITECTURE.md § Data model):
- `rondas/{id}/weeks/{isoWeek}`: `date`, the raw `rsvp {uid: yes | no}` and `rsvpSentAt`, the
  mark that makes the push once a week. No client reads it.
- `rondas/{id}/views/week`: what members read for the upcoming meeting: the yeses' first names
  and what they bring, and only counts for "no puede" and "sin contestar".
- `rondas/{id}/answers/{uid}`: the member's own answer, read by that member only.

Nothing here talks to FCM: `rsvp_messages` builds HTTP v1 messages as plain dicts and the
caller's `send` delivers them (main.py), so the tests and the emulator never reach Google. No
address ever goes into a push: the line names the pretext and, once the admin sets them, the
hour and the public place's name; until then the body says "Lugar y hora a confirmar.". Logs
carry counts only, never a token or a uid.
"""

import logging
from collections.abc import Callable, Iterable
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

log = logging.getLogger(__name__)

MONTEVIDEO = ZoneInfo("America/Montevideo")
DAYS = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")

YES = "yes"
NO = "no"
ANSWERS = (YES, NO)

DEFAULT_LEAD = {"daysBefore": 2, "hour": 19}
"""docs/PRODUCT.md § The weekly loop: two days before at 19:00 (Tuesday for a Thursday ronda)."""

QUIET_FROM = 21
QUIET_UNTIL = 9
"""The gate: nothing goes out between 21:00 and 09:00 in Montevideo."""

PAUSE_WEEKS = 2
""""Pausar 2 semanas" on the Esta no sheet: this meeting and the next."""

OPEN_STATUSES = ("forming", "active")
"""Rondas that still meet; `paused` and `ended` get no push."""

RSVP_TYPE = "rsvp"
"""`data.type` of the push, which the phone draws with [Voy] [Esta no]."""

VIEW = "week"
"""`rondas/{id}/views/{VIEW}`."""

NAMES_IN_PUSH = 4
"""At most this many first names in "Ya van …"; the rest is "y 2 más"."""

DAY_LABELS = {
    "mon": "Lunes",
    "tue": "Martes",
    "wed": "Miércoles",
    "thu": "Jueves",
    "fri": "Viernes",
    "sat": "Sábado",
    "sun": "Domingo",
}
BAND_LABELS = {"morning": "a la mañana", "afternoon": "a la tarde", "evening": "a la noche"}
BANDS = {"morning": (9, 12), "afternoon": (14, 18), "evening": (19, 21)}
"""Each time band from its first hour to its end (docs/PRODUCT.md § Onboarding: "Mañana: de 9 a
12 · Tarde: de 14 a 18 · Noche: de 19 a 21")."""

MEETING_HOURS = 1
"""A ronda's hour (`slot.hour`) starts inside its band at least this many hours before the
band ends, so the meeting fits: 9:00 to 11:00, 14:00 to 17:00, 19:00 to 20:00."""

PRETEXT_LABELS = {
    "mate": "mate en la rambla",
    "truco": "truco",
    "futbol5": "fútbol 5",
    "caminata": "caminata",
}
BRING_TURNS = {
    "pan": "Te toca llevar el pan.",
    "yerba": "Te toca llevar la yerba.",
    "termo": "Te toca llevar el termo.",
    "sillas": "Te toca llevar las sillas.",
    "enseno-truco": "Te toca enseñar truco.",
}
"""The es-419 push names what each member brings; `tengo-ganas` brings nothing to name."""


class RsvpError(Exception):
    """An answer the callable refuses; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


# --- Time ---------------------------------------------------------------------------------


def local(now: datetime) -> datetime:
    """`now` (aware) in Montevideo."""
    return now.astimezone(MONTEVIDEO)


def iso_week(day: date) -> str:
    """`2026-W44`: the ISO week a meeting falls in, the id of its `weeks/` document."""
    year, week, _ = day.isocalendar()
    return f"{year}-W{week:02d}"


def next_meeting(slot_day: str, today: date) -> date:
    """The ronda's next meeting date on or after `today`: on the day itself it is that day's."""
    return today + timedelta(days=(DAYS.index(slot_day) - today.weekday()) % 7)


def lead(ronda: dict) -> dict:
    """The ronda's `rsvpLead`, or the default when it is missing or out of range: one to six
    days before, at a whole hour inside the gate."""
    value = ronda.get("rsvpLead")
    if not isinstance(value, dict):
        return dict(DEFAULT_LEAD)
    days, hour = value.get("daysBefore"), value.get("hour")
    if not isinstance(days, int) or not 1 <= days <= 6:
        days = DEFAULT_LEAD["daysBefore"]
    if not isinstance(hour, int) or not QUIET_UNTIL <= hour < QUIET_FROM:
        hour = DEFAULT_LEAD["hour"]
    return {"daysBefore": days, "hour": hour}


def push_due_at(meeting: date, ronda: dict) -> datetime:
    """When the RSVP for `meeting` is due, in Montevideo."""
    rule = lead(ronda)
    day = meeting - timedelta(days=rule["daysBefore"])
    return datetime.combine(day, time(rule["hour"]), tzinfo=MONTEVIDEO)


def inside_gate(now: datetime) -> bool:
    """Whether a message may go out now: 09:00 to 21:00 in Montevideo."""
    return QUIET_UNTIL <= local(now).hour < QUIET_FROM


# --- Where and when a ronda meets ---------------------------------------------------------


def hour_in_band(hour: object, band: object) -> bool:
    """Whether `hour` ("16:30") is a start the ronda's time band allows (`MEETING_HOURS`)."""
    if not isinstance(hour, str) or band not in BANDS:
        return False
    try:
        start = time.fromisoformat(hour)
    except ValueError:
        return False
    first, end = BANDS[band]
    return len(hour) == 5 and time(first) <= start <= time(end - MEETING_HOURS)


def meeting_hour(ronda: dict) -> str | None:
    """The hour the ronda meets ("16:00"), once the admin set one inside its band."""
    slot = ronda.get("slot") or {}
    hour = slot.get("hour")
    return hour if hour_in_band(hour, slot.get("time")) else None


def place_name(ronda: dict) -> str | None:
    """The public place's name, once the admin set one."""
    place = ronda.get("place")
    if isinstance(place, dict) and isinstance(place.get("name"), str) and place["name"]:
        return place["name"]
    return None


def to_confirm(ronda: dict) -> str:
    """ "Lugar y hora a confirmar.": what the ronda doesn't know yet, so nobody invents it."""
    place, hour = place_name(ronda) is not None, meeting_hour(ronda) is not None
    if place and hour:
        return ""
    if hour:
        return "Lugar a confirmar."
    if place:
        return "Hora a confirmar."
    return "Lugar y hora a confirmar."


# --- The view members read ----------------------------------------------------------------


def _paused_on(member: dict, meeting: date) -> bool:
    return member.get("state") == "paused" and member.get("pausedUntil", "") > meeting.isoformat()


def counted(members: dict[str, dict]) -> dict[str, dict]:
    """The members a week counts: everyone but those who left."""
    return {uid: m for uid, m in members.items() if m.get("state", "active") != "left"}


def guests(snapshot) -> dict[str, dict]:
    """`weeks/{w}.guests {uid: {firstName, brings, offerId, at}}`: who took a seat freed by an
    "esta no" from the bench for that meeting (bench.py). A guest goes that week only and is no
    member: the view lists them as going, nothing else counts them."""
    return dict((snapshot.to_dict() or {}).get("guests", {})) if snapshot.exists else {}


def yes_uids(rsvp: dict[str, str], members: dict[str, dict], names: dict[str, str]) -> list[str]:
    """The members who said yes, in first-name order."""
    uids = [uid for uid, value in rsvp.items() if value == YES and uid in counted(members)]
    return sorted(uids, key=lambda uid: (names.get(uid, ""), uid))


def week_view(
    meeting: date,
    members: dict[str, dict],
    first_names: dict[str, str],
    rsvp: dict[str, str],
    now: datetime,
    guests: dict[str, dict] | None = None,
) -> dict:
    """`rondas/{id}/views/week`: the yeses by first name with what they bring, and only counts
    for the rest. A member paused over this meeting who didn't answer counts as "no puede".
    `guests` (`weeks/{w}.guests`) go too, marked `guest`, in first-name order with the rest."""
    no = unanswered = 0
    for uid, member in counted(members).items():
        value = rsvp.get(uid)
        if value == YES:
            continue
        if value == NO or _paused_on(member, meeting):
            no += 1
        else:
            unanswered += 1
    going = [
        {
            "uid": uid,
            "firstName": first_names.get(uid, ""),
            "brings": list(members[uid].get("brings", [])),
        }
        for uid in yes_uids(rsvp, members, first_names)
    ]
    going += [
        {
            "uid": uid,
            "firstName": guest.get("firstName", ""),
            "brings": list(guest.get("brings", [])),
            "guest": True,
        }
        for uid, guest in (guests or {}).items()
        if uid not in counted(members)
    ]
    going.sort(key=lambda person: (person["firstName"], person["uid"]))
    return {
        "week": iso_week(meeting),
        "date": meeting.isoformat(),
        "going": going,
        "noCount": no,
        "unansweredCount": unanswered,
        "updatedAt": now,
    }


# --- The push -----------------------------------------------------------------------------


def ronda_line(ronda: dict) -> str:
    """ "Sábado 16:00 · mate en la rambla · frente al quiosco": the hour and the public place
    once the admin set them; until then the band ("Sábado a la tarde") and no place."""
    slot = ronda.get("slot", {})
    hour = meeting_hour(ronda) or BAND_LABELS.get(slot.get("time"), "")
    when = f"{DAY_LABELS.get(slot.get('day'), '')} {hour}"
    parts = [when.strip(), PRETEXT_LABELS.get(ronda.get("pretext"), ronda.get("pretext", ""))]
    if place := place_name(ronda):
        parts.append(place)
    return " · ".join(part for part in parts if part)


def _names(names: list[str]) -> str:
    shown = names[:NAMES_IN_PUSH]
    rest = len(names) - len(shown)
    if rest:
        return f"{', '.join(shown)} y {rest} más"
    if len(shown) == 1:
        return shown[0]
    return f"{', '.join(shown[:-1])} y {shown[-1]}"


def push_body(going_names: list[str], brings: Iterable[str], *, unknown: str = "") -> str:
    """ "Ya van Mirta y Jorge. Te toca llevar el pan. ¿Venís?": who's coming so far, what this
    member brings, and the question; `unknown` ("Lugar y hora a confirmar.") goes first."""
    sentences = [unknown] if unknown else []
    if going_names:
        verb = "Ya va" if len(going_names) == 1 else "Ya van"
        sentences.append(f"{verb} {_names(going_names)}.")
    if turn := next((BRING_TURNS[b] for b in brings if b in BRING_TURNS), None):
        sentences.append(turn)
    sentences.append("¿Venís?")
    return " ".join(sentences)


def rsvp_messages(
    *,
    tokens: list[tuple[str, str]],
    title: str,
    body: str,
    ronda_id: str,
    week: str,
    app_url: str,
) -> list[dict]:
    """One HTTP v1 message per `(token, platform)`, as docs/STACK.md § Push sets out.

    Android gets a data-only message at high priority, which the phone draws with [Voy] and
    [Esta no]; web gets a plain notification that opens the card. iPhones are skipped until
    the Apple Developer Program exists.
    """
    messages = []
    for token, platform in tokens:
        if platform == "android":
            messages.append(
                {
                    "token": token,
                    "data": {
                        "type": RSVP_TYPE,
                        "rondaId": ronda_id,
                        "week": week,
                        "title": title,
                        "body": body,
                    },
                    "android": {"priority": "HIGH"},
                }
            )
        elif platform == "web":
            messages.append(
                {
                    "token": token,
                    "notification": {"title": title, "body": body},
                    "webpush": {"fcm_options": {"link": app_url}},
                }
            )
    return messages


# --- Reading and writing ------------------------------------------------------------------


def _in_transaction(db, function: Callable):
    from google.cloud import firestore

    return firestore.transactional(function)(db.transaction())


def _members(db, ronda_id: str) -> dict[str, dict]:
    return {s.id: s.to_dict() for s in db.collection(f"rondas/{ronda_id}/members").stream()}


def _first_names(db, uids: Iterable[str]) -> dict[str, str]:
    names = {}
    for uid in uids:
        snapshot = db.document(f"users/{uid}").get()
        names[uid] = (snapshot.to_dict() or {}).get("firstName", "") if snapshot.exists else ""
    return names


def _sent(snapshot) -> bool:
    return snapshot.exists and bool((snapshot.to_dict() or {}).get("rsvpSentAt"))


def _rsvp(snapshot) -> dict[str, str]:
    return dict((snapshot.to_dict() or {}).get("rsvp", {})) if snapshot.exists else {}


def _tokens(db, uid: str) -> list[tuple[str, str]]:
    return [
        (s.id, (s.to_dict() or {}).get("platform", ""))
        for s in db.collection(f"users/{uid}/tokens").stream()
    ]


def answer(
    db,
    uid: str,
    ronda_id: str,
    value: str,
    now: datetime,
    *,
    week: str | None = None,
    pause_weeks: int | None = None,
) -> dict:
    """Records `uid`'s answer for the ronda's upcoming meeting, and the view and their own
    answer with it, in one transaction.

    `week`, when given (the push's), must still be the upcoming meeting's, so an old
    notification can't answer next week. `pause_weeks` (only 2, only with "no") pauses the
    member through the meeting two weeks on; a "yes" ends a pause.
    """
    from google.cloud.firestore import DELETE_FIELD

    if value not in ANSWERS:
        raise RsvpError("invalid-argument", "answer is yes or no")
    if pause_weeks is not None and (pause_weeks != PAUSE_WEEKS or value != NO):
        raise RsvpError("invalid-argument", "only a no pauses, for 2 weeks")
    ronda_snapshot = db.document(f"rondas/{ronda_id}").get()
    if not ronda_snapshot.exists:
        raise RsvpError("not-found", "no such ronda")
    ronda = ronda_snapshot.to_dict()
    members = _members(db, ronda_id)
    if uid not in counted(members):
        raise RsvpError("permission-denied", "not a member of this ronda")
    meeting = next_meeting(ronda["slot"]["day"], local(now).date())
    current = iso_week(meeting)
    if week is not None and week != current:
        raise RsvpError("failed-precondition", "that meeting has passed")

    member = dict(members[uid])
    member_update: dict = {}
    if pause_weeks is not None:
        member_update = {
            "state": "paused",
            "pausedUntil": (meeting + timedelta(weeks=pause_weeks)).isoformat(),
        }
        member.update(member_update)
    elif value == YES and member.get("state") == "paused":
        member_update = {"state": "active", "pausedUntil": DELETE_FIELD}
        member["state"] = "active"
        member.pop("pausedUntil", None)
    members[uid] = member
    names = _first_names(db, members)
    week_ref = db.document(f"rondas/{ronda_id}/weeks/{current}")

    def write(transaction) -> None:
        week = week_ref.get(transaction=transaction)
        rsvp = _rsvp(week)
        rsvp[uid] = value
        transaction.set(week_ref, {"date": meeting.isoformat(), "rsvp": {uid: value}}, merge=True)
        transaction.set(
            db.document(f"rondas/{ronda_id}/views/{VIEW}"),
            week_view(meeting, members, names, rsvp, now, guests(week)),
        )
        transaction.set(
            db.document(f"rondas/{ronda_id}/answers/{uid}"),
            {"week": current, "answer": value, "at": now},
        )
        if member_update:
            transaction.update(db.document(f"rondas/{ronda_id}/members/{uid}"), member_update)

    _in_transaction(db, write)
    return {"week": current, "answer": value}


def run_rsvp_push(
    db,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
    force: bool = False,
) -> dict:
    """The hourly RSVP job. For each ronda that still meets it keeps `views/week` on the
    upcoming meeting and, when that meeting's push is due and not sent yet, sends it.

    Due means the lead time has come and the meeting isn't today; `force` (the admin's
    button) skips both. It is held from 21:00 to 09:00 and tried again on the next run.
    `rsvpSentAt` on the week, set in a transaction before sending, makes it once per ronda and
    week; if sending fails outright the mark is taken back so the next run tries again.

    `send` delivers HTTP v1 message dicts and returns one outcome per message: `ok`,
    `unregistered` (that token is deleted) or anything else. Returns counts.
    """
    from google.cloud.firestore import DELETE_FIELD

    counts = {"rondas": 0, "pushed": 0, "messages": 0, "already": 0, "held": 0}
    today = local(now).date()
    for snapshot in db.collection("rondas").stream():
        ronda = snapshot.to_dict()
        if ronda.get("status") not in OPEN_STATUSES:
            continue
        counts["rondas"] += 1
        ronda_id = snapshot.id
        meeting = next_meeting(ronda["slot"]["day"], today)
        members = _members(db, ronda_id)
        names = _first_names(db, members)
        week_ref = db.document(f"rondas/{ronda_id}/weeks/{iso_week(meeting)}")
        _roll_view(db, ronda_id, week_ref, meeting, members, names, now)

        if not (force or (meeting > today and push_due_at(meeting, ronda) <= now)):
            continue
        if not inside_gate(now):
            counts["held"] += 1
            continue
        if not _in_transaction(db, _claim(week_ref, meeting, now)):
            counts["already"] += 1
            continue
        try:
            delivered = _send_week(
                db, ronda, ronda_id, week_ref, meeting, members, names, now, send, app_url
            )
        except Exception:
            week_ref.update({"rsvpSentAt": DELETE_FIELD})
            raise
        counts["pushed"] += 1
        counts["messages"] += delivered
    log.info("rsvp_push: %s", counts)
    return counts


def _roll_view(db, ronda_id, week_ref, meeting, members, names, now) -> None:
    """Moves `views/week` to the upcoming meeting once the last one has passed."""
    view_ref = db.document(f"rondas/{ronda_id}/views/{VIEW}")

    def roll(transaction) -> None:
        view = view_ref.get(transaction=transaction)
        week = week_ref.get(transaction=transaction)
        if view.exists and (view.to_dict() or {}).get("week") == iso_week(meeting):
            return
        view_now = week_view(meeting, members, names, _rsvp(week), now, guests(week))
        transaction.set(view_ref, view_now)

    _in_transaction(db, roll)


def _claim(week_ref, meeting: date, now: datetime) -> Callable:
    def claim(transaction) -> bool:
        if _sent(week_ref.get(transaction=transaction)):
            return False
        transaction.set(week_ref, {"date": meeting.isoformat(), "rsvpSentAt": now}, merge=True)
        return True

    return claim


def _send_week(db, ronda, ronda_id, week_ref, meeting, members, names, now, send, app_url) -> int:
    """The week's push: closes an open ¿seguimos? first (seguimos.close), whose outcome this
    push carries, then sends the RSVP and what the close adds. Returns how many messages
    were delivered."""
    import seguimos  # here, not at the top: seguimos imports this module

    closing = seguimos.close(db, ronda_id, ronda, members, meeting, now)
    if closing is None:
        return _send_ronda(db, ronda, ronda_id, week_ref, meeting, members, names, send, app_url)[0]
    week = week_ref.get()
    db.document(f"rondas/{ronda_id}/views/{VIEW}").set(
        week_view(meeting, closing.members, names, _rsvp(week), now, guests(week))
    )
    delivered, pushed = 0, set()
    if closing.rsvp_goes_out:
        delivered, pushed = _send_ronda(
            db, ronda, ronda_id, week_ref, meeting, closing.members, names, send, app_url,
            lead_in=closing.words,
        )  # fmt: skip
    return delivered + seguimos.send_results(db, closing, ronda, ronda_id, pushed, send, app_url)


def _send_ronda(
    db, ronda, ronda_id, week_ref, meeting, members, names, send, app_url, *, lead_in: str = ""
) -> tuple[int, set[str]]:
    """Sends the push to every member in for `meeting` who hasn't answered yet, with
    `lead_in` before the body; returns how many messages were delivered and who it addressed."""
    rsvp = _rsvp(week_ref.get())
    going = [names[uid] for uid in yes_uids(rsvp, members, names) if names[uid]]
    title = ronda_line(ronda)
    messages, owners, addressed = [], [], set()
    for uid, member in counted(members).items():
        if uid in rsvp or _paused_on(member, meeting):
            continue
        addressed.add(uid)
        body = push_body(going, member.get("brings", []), unknown=to_confirm(ronda))
        for message in rsvp_messages(
            tokens=_tokens(db, uid),
            title=title,
            body=f"{lead_in} {body}" if lead_in else body,
            ronda_id=ronda_id,
            week=iso_week(meeting),
            app_url=app_url,
        ):
            messages.append(message)
            owners.append(uid)
    if not messages:
        return 0, addressed
    outcomes = send(messages)
    for message, uid, outcome in zip(messages, owners, outcomes, strict=True):
        if outcome == "unregistered":
            db.document(f"users/{uid}/tokens/{message['token']}").delete()
    return sum(1 for outcome in outcomes if outcome == "ok"), addressed
