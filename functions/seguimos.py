"""¿Seguimos? after a ronda's first meeting, and the season (docs/PRODUCT.md § First visit, #9).

`run_seguimos_ask(db, now, send=...)` is the job the hourly dispatcher and the admin's `run_job`
call: on the evening after a ronda's first meeting it asks every active member, privately and
once per ronda, whether they go on. `answer(db, uid, ronda_id, now, ...)` is the
`answer_seguimos` callable's body: a "sí" or "no" while the question is open, and after a close
below the floor the member's pick between "Sumarte a otro ya" and "Esperar dos semanas más".
`close(...)` runs inside the ronda's next RSVP push (rsvp.run_rsvp_push), which carries the
outcome.

The rule (#9): the season starts when the yeses alone could be a ronda, the pretext's floor in
the solver (`SizeRule.floor`). Not answering keeps the seat and isn't a yes. A "no" gets
"Gracias por venir." with up to two nearby rondas with places, and that seat reopens at the
close, never on answering, so the timing gives nobody away. Below the floor there is no season
and everyone still in gets the "didn't fill" choices with dates.

Where things live (docs/ARCHITECTURE.md § Data model):
- `rondas/{id}/private/seguimos`: askedAt, asked [uids], answers {uid: yes | no}, choices
  {uid: join | wait}, closedAt, outcome. No client reads it.
- `rondas/{id}/seguimos/{uid}`: the member's own question and what came of it, read by that
  member only: status (open | closed), answer?, outcome? (season | gracias | didntFill),
  alternatives?, wait?, choice?.
- `seguimos_counts/{rondaId}`: what /admin shows, counts only, read by the admin claim only.
- The outcome lands on the ronda as `season {start, end}` (ISO dates of its first and last
  meeting). Members see that, never a count or a name.

Logs carry counts only, never a token or a uid.
"""

import logging
from collections.abc import Callable
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta

import rsvp

log = logging.getLogger(__name__)

ASK_HOUR = 20
"""The ask goes out at 20:00 in Montevideo on the meeting's day: an afternoon band ends at 18:00
and a mate on the rambla runs to about sunset, so people are home, the meeting is fresh, and an
hour is left before the 21:00 gate in case a run is missed (the next try is 09:00). An evening
band (19 to 21) is asked the next day at the same hour."""

SEASON_WEEKS = 4
"""How many weekly meetings a season holds, counting the first. Owner decision (#46): PRODUCT
gives no length. Four is one host rotation (hosts change monthly), a small ask after a single
meeting, and it ends the pilot's season on 11-24, before the pilot's data is deleted."""

WAIT_WEEKS = 2
""""Esperar dos semanas más" (docs/PRODUCT.md § Seats, Didn't fill)."""

ALTERNATIVES = 2
"""A "no" gets up to this many nearby rondas with places."""

ASK_TYPE = "seguimos"
"""`data.type` of the ask, which the phone draws with [Sí] [No]."""

RESULT_TYPE = "seguimosResult"
"""`data.type` of what the close sends besides the RSVP: drawn plain, without buttons."""

OPEN, CLOSED = "open", "closed"
SEASON, GRACIAS, DIDNT_FILL = "season", "gracias", "didntFill"
JOIN, WAIT = "join", "wait"
CHOICES = (JOIN, WAIT)

DAY_PLURALS = {
    "mon": "lunes",
    "tue": "martes",
    "wed": "miércoles",
    "thu": "jueves",
    "fri": "viernes",
    "sat": "sábados",
    "sun": "domingos",
}

ASK_BODY = (
    "¿Seguimos los {days}? Solo Ronda ve tu respuesta. Nadie del grupo se entera de lo que digas."
)


class SeguimosError(Exception):
    """An answer the callable refuses; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


# --- Time ---------------------------------------------------------------------------------


def first_meeting(ronda: dict, week_dates: list[date]) -> date | None:
    """The ronda's first meeting: its earliest `weeks/` date, which outlives a later change of
    `slot.day`; with none, the slot's first day on or after the ronda was approved."""
    if week_dates:
        return min(week_dates)
    created = ronda.get("createdAt")
    if not isinstance(created, datetime):
        return None
    return rsvp.next_meeting(ronda["slot"]["day"], rsvp.local(created).date())


def ask_due_at(meeting: date, ronda: dict) -> datetime:
    """When the ask for a first meeting on `meeting` is due, in Montevideo."""
    evening = ronda.get("slot", {}).get("time") == "evening"
    day = meeting + timedelta(days=1 if evening else 0)
    return datetime.combine(day, time(ASK_HOUR), tzinfo=rsvp.MONTEVIDEO)


def season_for(meeting: date) -> dict:
    """The season that starts with `meeting`: its first and last meeting, as ISO dates."""
    return {
        "start": meeting.isoformat(),
        "end": (meeting + timedelta(weeks=SEASON_WEEKS - 1)).isoformat(),
    }


def wait_for(meeting: date) -> dict:
    """ "Esperar dos semanas más" after a close before `meeting`: the ronda would start two
    meetings later, if enough join by the day before."""
    start = meeting + timedelta(weeks=WAIT_WEEKS)
    return {"until": (start - timedelta(days=1)).isoformat(), "start": start.isoformat()}


def spoken_date(day: date) -> str:
    """ "martes 24/11"."""
    weekday = rsvp.DAY_LABELS[rsvp.DAYS[day.weekday()]].lower()
    return f"{weekday} {day.day}/{day.month}"


def day_plural(ronda: dict) -> str:
    """ "sábados": the ronda's slot day, read when the words are written."""
    return DAY_PLURALS.get(ronda.get("slot", {}).get("day"), "")


# --- The words ----------------------------------------------------------------------------


def season_words(ronda: dict, season: dict) -> str:
    """What goes before the RSVP push when the season starts (#9): no count, no names."""
    end = spoken_date(date.fromisoformat(season["end"]))
    return f"Seguimos los {day_plural(ronda)}, hasta el {end}. Nadie sabe qué contestó cada uno."


def gracias_words(alternatives: list[dict]) -> str:
    """The body of a "no"'s push: the nearby rondas with places, by their line only."""
    if not alternatives:
        return "Por ahora no hay otro grupo con lugar cerca. Te avisamos si se abre uno."
    rows = [
        f"{alternative['line']} (quedan {alternative['placesLeft']})"
        if alternative["placesLeft"] > 1
        else f"{alternative['line']} (queda 1)"
        for alternative in alternatives
    ]
    return f"Hay lugar cerca: {' y '.join(rows)}. Los ves en Ronda."


def didnt_fill_words(ronda: dict, floor: int, wait: dict) -> str:
    """The body for everyone still in when the yeses don't reach the floor."""
    until = spoken_date(date.fromisoformat(wait["until"]))
    return (
        f"Esta vez no llegamos a {floor} para seguir los {day_plural(ronda)}. "
        f"Elegí en Ronda: sumarte a otro grupo ya, o esperar hasta el {until}."
    )


# --- Messages -----------------------------------------------------------------------------


def messages(
    *,
    tokens: list[tuple[str, str]],
    kind: str,
    ronda_id: str,
    title: str,
    body: str,
    app_url: str,
) -> list[dict]:
    """One HTTP v1 message per `(token, platform)`, shaped like the RSVP push (docs/STACK.md
    § Push): data-only at high priority on Android, which draws the ask with [Sí] [No]; a
    plain notification that opens the card on web; nothing for iPhones yet."""
    out = []
    for token, platform in tokens:
        if platform == "android":
            out.append(
                {
                    "token": token,
                    "data": {"type": kind, "rondaId": ronda_id, "title": title, "body": body},
                    "android": {"priority": "HIGH"},
                }
            )
        elif platform == "web":
            out.append(
                {
                    "token": token,
                    "notification": {"title": title, "body": body},
                    "webpush": {"fcm_options": {"link": app_url}},
                }
            )
    return out


def deliver(db, send: Callable[[list[dict]], list[str]], batch: list[tuple[str, dict]]) -> int:
    """Sends each `(uid, message)` and returns how many FCM accepted; deletes a token FCM no
    longer knows."""
    if not batch:
        return 0
    outcomes = send([message for _, message in batch])
    for (uid, message), outcome in zip(batch, outcomes, strict=True):
        if outcome == "unregistered":
            db.document(f"users/{uid}/tokens/{message['token']}").delete()
    return sum(1 for outcome in outcomes if outcome == "ok")


# --- Counts the admin reads ---------------------------------------------------------------


def tally(asked: list[str], answers: dict[str, str]) -> dict:
    """sí / no / sin contestar among the members asked."""
    yes = sum(1 for uid in asked if answers.get(uid) == rsvp.YES)
    no = sum(1 for uid in asked if answers.get(uid) == rsvp.NO)
    return {"asked": len(asked), "yes": yes, "no": no, "unanswered": len(asked) - yes - no}


def choice_counts(choices: dict[str, str]) -> dict:
    return {choice: sum(1 for value in choices.values() if value == choice) for choice in CHOICES}


# --- The ask ------------------------------------------------------------------------------


def _paths(ronda_id: str) -> tuple[str, str]:
    return f"rondas/{ronda_id}/private/seguimos", f"seguimos_counts/{ronda_id}"


def _open(private: dict) -> bool:
    return bool(private.get("askedAt")) and not private.get("closedAt")


def _claim_ask(private_ref, asked: list[str], first: date | None, now: datetime) -> Callable:
    def claim(transaction) -> bool:
        if private_ref.get(transaction=transaction).exists:
            return False
        transaction.set(
            private_ref,
            {
                "askedAt": now,
                "firstMeeting": first.isoformat() if first else None,
                "asked": asked,
                "answers": {},
                "choices": {},
            },
        )
        return True

    return claim


def run_seguimos_ask(
    db,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
    force: bool = False,
) -> dict:
    """The hourly ¿seguimos? job. For each ronda that still meets and has no season, once its
    first meeting is over (`ask_due_at`), asks every active member, once per ronda.

    The `private/seguimos` document, created in a transaction before sending, makes it once per
    ronda. The window ends when the RSVP push for a later meeting has gone out: asked after
    that, the question would close a week late, so the ronda is marked and never asked. Held
    from 21:00 to 09:00 and tried again on the next run. `force` (the admin's `run_job`) skips
    the timing, never the gate or the once-per-ronda mark.
    """
    counts = {"asked": 0, "messages": 0, "already": 0, "held": 0, "late": 0}
    for snapshot in db.collection("rondas").stream():
        ronda = snapshot.to_dict()
        if ronda.get("status") not in rsvp.OPEN_STATUSES or ronda.get("season"):
            continue
        ronda_id = snapshot.id
        private_path, counts_path = _paths(ronda_id)
        private_ref = db.document(private_path)
        if private_ref.get().exists:
            continue
        weeks = [s.to_dict() or {} for s in db.collection(f"rondas/{ronda_id}/weeks").stream()]
        dates = [date.fromisoformat(w["date"]) for w in weeks if isinstance(w.get("date"), str)]
        first = first_meeting(ronda, dates)
        if not force:
            if first is None or now < ask_due_at(first, ronda):
                continue
            if any(
                w.get("rsvpSentAt") and date.fromisoformat(w["date"]) > first
                for w in weeks
                if isinstance(w.get("date"), str)
            ):
                private_ref.set({"skipped": "late", "skippedAt": now})
                counts["late"] += 1
                continue
        if not rsvp.inside_gate(now):
            counts["held"] += 1
            continue
        members = rsvp._members(db, ronda_id)
        asked = sorted(uid for uid, member in members.items() if member.get("state") == "active")

        if not rsvp._in_transaction(db, _claim_ask(private_ref, asked, first, now)):
            counts["already"] += 1
            continue
        batch = db.batch()
        for uid in asked:
            batch.set(
                db.document(f"rondas/{ronda_id}/seguimos/{uid}"), {"status": OPEN, "askedAt": now}
            )
        batch.set(
            db.document(counts_path),
            {
                "line": rsvp.ronda_line(ronda),
                "status": OPEN,
                **tally(asked, {}),
                "choices": choice_counts({}),
                "askedAt": now,
                "updatedAt": now,
            },
        )
        batch.commit()
        title, body = rsvp.ronda_line(ronda), ASK_BODY.format(days=day_plural(ronda))
        outgoing = [
            (uid, message)
            for uid in asked
            for message in messages(
                tokens=rsvp._tokens(db, uid),
                kind=ASK_TYPE,
                ronda_id=ronda_id,
                title=title,
                body=body,
                app_url=app_url,
            )
        ]
        try:
            counts["messages"] += deliver(db, send, outgoing)
        except Exception:
            private_ref.delete()
            raise
        counts["asked"] += 1
    log.info("seguimos_ask: %s", counts)
    return counts


# --- The answer ---------------------------------------------------------------------------


def answer(
    db,
    uid: str,
    ronda_id: str,
    now: datetime,
    *,
    value: str | None = None,
    choice: str | None = None,
) -> dict:
    """Records `uid`'s "sí" or "no" (`value`) while the question is open, or after a close
    below the floor their `choice` (join | wait). Members of that ronda only, and only who was
    asked or is still in at the close."""
    if (value is None) == (choice is None):
        raise SeguimosError("invalid-argument", "send an answer or a choice")
    if value is not None and value not in rsvp.ANSWERS:
        raise SeguimosError("invalid-argument", "answer is yes or no")
    if choice is not None and choice not in CHOICES:
        raise SeguimosError("invalid-argument", "choice is join or wait")
    if not db.document(f"rondas/{ronda_id}").get().exists:
        raise SeguimosError("not-found", "no such ronda")
    if not db.document(f"rondas/{ronda_id}/members/{uid}").get().exists:
        raise SeguimosError("permission-denied", "not a member of this ronda")
    private_path, counts_path = _paths(ronda_id)
    private_ref, counts_ref = db.document(private_path), db.document(counts_path)
    own_ref = db.document(f"rondas/{ronda_id}/seguimos/{uid}")

    def write(transaction) -> None:
        private_snapshot = private_ref.get(transaction=transaction)
        own_snapshot = own_ref.get(transaction=transaction)
        private = (private_snapshot.to_dict() or {}) if private_snapshot.exists else {}
        own = (own_snapshot.to_dict() or {}) if own_snapshot.exists else {}
        if value is not None:
            if not _open(private) or own.get("status") != OPEN:
                raise SeguimosError("failed-precondition", "the question is closed")
            answers = {**private.get("answers", {}), uid: value}
            transaction.set(private_ref, {"answers": {uid: value}}, merge=True)
            transaction.set(own_ref, {"answer": value, "answeredAt": now}, merge=True)
            transaction.set(
                counts_ref,
                {**tally(private.get("asked", []), answers), "updatedAt": now},
                merge=True,
            )
            return
        if own.get("outcome") != DIDNT_FILL:
            raise SeguimosError("failed-precondition", "there is nothing to choose")
        choices = {**private.get("choices", {}), uid: choice}
        transaction.set(private_ref, {"choices": {uid: choice}}, merge=True)
        transaction.set(own_ref, {"choice": choice, "choiceAt": now}, merge=True)
        transaction.set(
            counts_ref, {"choices": choice_counts(choices), "updatedAt": now}, merge=True
        )

    rsvp._in_transaction(db, write)
    return {"answer": value} if value is not None else {"choice": choice}


# --- The close ----------------------------------------------------------------------------


@dataclass(frozen=True)
class Closing:
    """What a close decided, for the RSVP push that carries it."""

    outcome: str
    """`season` or `didntFill`."""

    members: dict[str, dict]
    """The ronda's members after the close: each "no" has left."""

    leaving: list[str]
    """The members who said no."""

    words: str
    """The season's words before the RSVP body, or the didn't-fill body."""

    alternatives: list[dict]

    @property
    def rsvp_goes_out(self) -> bool:
        """The RSVP push goes out only when the ronda goes on."""
        return self.outcome == SEASON


def alternatives(db, ronda_id: str, ronda: dict, today: date) -> list[dict]:
    """Up to `ALTERNATIVES` rondas within the solver's walking distance of this one, still
    meeting and with places: same pretext first, then the nearest. Each by its line without a
    place, its ids, places left and next meeting; no name, place or member leaves."""
    # Both import the solver package, and with it OR-Tools: only a close pays for that.
    from proposals import BARRIOS
    from ronda_solver.geo import blocks_between
    from ronda_solver.rules import MAX_WALK_BLOCKS, size_rule

    here = BARRIOS.get(ronda.get("barrio"))
    if here is None:
        return []
    found = []
    for snapshot in db.collection("rondas").stream():
        other = snapshot.to_dict()
        there = BARRIOS.get(other.get("barrio"))
        if snapshot.id == ronda_id or other.get("status") not in rsvp.OPEN_STATUSES or not there:
            continue
        blocks = blocks_between((here["lat"], here["lng"]), (there["lat"], there["lng"]))
        if blocks > MAX_WALK_BLOCKS:
            continue
        taken = sum(
            1
            for member in db.collection(f"rondas/{snapshot.id}/members").stream()
            if (member.to_dict() or {}).get("state") in ("active", "paused")
        )
        places = size_rule(other.get("pretext")).cap - taken
        if places <= 0:
            continue
        line = rsvp.ronda_line({key: value for key, value in other.items() if key != "place"})
        found.append(
            (
                other.get("pretext") != ronda.get("pretext"),
                blocks,
                snapshot.id,
                {
                    "rondaId": snapshot.id,
                    "line": line,
                    "pretext": other.get("pretext"),
                    "barrio": other.get("barrio"),
                    "slot": dict(other.get("slot", {})),
                    "placesLeft": places,
                    "next": rsvp.next_meeting(other["slot"]["day"], today).isoformat(),
                },
            )
        )
    found.sort(key=lambda row: row[:3])
    return [row[3] for row in found[:ALTERNATIVES]]


def close(
    db, ronda_id: str, ronda: dict, members: dict[str, dict], meeting: date, now: datetime
) -> Closing | None:
    """Closes the ronda's open ¿seguimos?, if there is one, before the RSVP push for `meeting`
    goes out; `None` when nothing is open. In one transaction: the outcome, the season on the
    ronda (which then is `active`), each "no" leaving, every member's own result and the
    admin's counts. `ronda` is read at send time, so a `slot.day` the admin changed after the
    first meeting is the day the words name."""
    from ronda_solver.rules import size_rule

    private_path, counts_path = _paths(ronda_id)
    private_ref = db.document(private_path)
    snapshot = private_ref.get()
    if not snapshot.exists or not _open(snapshot.to_dict() or {}):
        return None
    nearby = alternatives(db, ronda_id, ronda, rsvp.local(now).date())
    floor = size_rule(ronda.get("pretext")).floor

    def decide(transaction) -> Closing | None:
        private = private_ref.get(transaction=transaction).to_dict() or {}
        if not _open(private):
            return None
        answers = private.get("answers", {})
        still = rsvp.counted(members)
        leaving = sorted(uid for uid in still if answers.get(uid) == rsvp.NO)
        yeses = sum(1 for uid in still if answers.get(uid) == rsvp.YES)
        outcome = SEASON if yeses >= floor else DIDNT_FILL
        season = season_for(meeting) if outcome == SEASON else None
        wait = wait_for(meeting)
        after = dict(members)
        for uid in leaving:
            after[uid] = {**members[uid], "state": "left"}
            transaction.update(
                db.document(f"rondas/{ronda_id}/members/{uid}"), {"state": "left", "leftAt": now}
            )
        for uid in still:
            result: dict = {"status": CLOSED, "closedAt": now}
            if uid in leaving:
                result.update(outcome=GRACIAS, alternatives=nearby)
            elif outcome == SEASON:
                result.update(outcome=SEASON)
            else:
                result.update(outcome=DIDNT_FILL, alternatives=nearby[:1], wait=wait, floor=floor)
            transaction.set(db.document(f"rondas/{ronda_id}/seguimos/{uid}"), result, merge=True)
        if season:
            transaction.update(
                db.document(f"rondas/{ronda_id}"), {"season": season, "status": "active"}
            )
        transaction.set(
            private_ref,
            {"closedAt": now, "outcome": outcome, "meeting": meeting.isoformat()},
            merge=True,
        )
        transaction.set(
            db.document(counts_path),
            {
                "line": rsvp.ronda_line(ronda),
                "status": outcome,
                **tally(private.get("asked", []), answers),
                "season": season,
                "closedAt": now,
                "updatedAt": now,
            },
            merge=True,
        )
        words = season_words(ronda, season) if season else didnt_fill_words(ronda, floor, wait)
        return Closing(outcome, after, leaving, words, nearby)

    return rsvp._in_transaction(db, decide)


def send_results(
    db,
    closing: Closing,
    ronda: dict,
    ronda_id: str,
    pushed: set[str],
    send: Callable[[list[dict]], list[str]],
    app_url: str,
) -> int:
    """What the close sends besides the RSVP push: "Gracias por venir." to each "no"; the
    season's words to whoever the RSVP push skipped (`pushed` holds who got it), or the
    didn't-fill words to everyone still in. Returns how many FCM accepted."""
    title = rsvp.ronda_line(ronda)
    outgoing = []
    for uid in closing.leaving:
        outgoing += [
            (uid, message)
            for message in messages(
                tokens=rsvp._tokens(db, uid),
                kind=RESULT_TYPE,
                ronda_id=ronda_id,
                title="Gracias por venir.",
                body=gracias_words(closing.alternatives),
                app_url=app_url,
            )
        ]
    for uid in rsvp.counted(closing.members):
        if uid in pushed:
            continue
        outgoing += [
            (uid, message)
            for message in messages(
                tokens=rsvp._tokens(db, uid),
                kind=RESULT_TYPE,
                ronda_id=ronda_id,
                title=title,
                body=closing.words,
                app_url=app_url,
            )
        ]
    return deliver(db, send, outgoing)
