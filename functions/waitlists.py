"""The waiting list's threshold with a deadline, and what happens when it doesn't fill
(docs/PRODUCT.md § Joining and forming rondas; #48).

"Con vos son 5 de 6. Falta uno. Si se suma uno más antes del domingo 1/11, empieza el sábado
7/11." And when the deadline passes short of the threshold: "Esta vez no llegamos a 6", with
"Sumarte a otro ya" (a named nearby ronda with places) or "Esperar dos semanas más" (a fixed end
date and start date). Each answer ends with the next date: never limbo.

- `run_waitlists(db, now)`: the job (`jobs.JOBS["waitlists"]`), hourly from the dispatcher. It
  rebuilds every list from the sign-ups, moves each list's round on when its deadline passed,
  and rewrites each waiting person's own card.
- `answer(db, uid, choice, now)`: the `answer_waitlist` callable's body: the person's pick after
  a round that didn't fill.

Who waits where: a sign-up with a profile who counts here (demo_users.counts), sits in no ronda
that still meets, and picked a barrio × pretext × slot whose seat id passes their needs filter
(their eligible ids) waits on that seat's list. A list's threshold is the pretext's largest
ronda (`SizeRule.cap`: 6, fútbol 10). A round runs to a Sunday (`deadline`, the whole day) and
the ronda would start on its slot's day the week after (`start`). At a deadline: a list at its
threshold rolls one week on (the admin's solver and approval make the ronda, as for any
sign-ups); one short of it closes as didn't-fill, and the next round is two weeks later, the
"Esperar dos semanas más" dates. Choices reset with each round.

Where things live (docs/ARCHITECTURE.md § Data model):
- `waitlists/{seatId}`: barrio, pretext, slot, threshold, entries [{uid, at}] (who waited
  longest first), round {deadline, start}, last {deadline, start, outcome (full | didntFill),
  closedAt}?, choices {uid: join | wait}, updatedAt. Server only.
- `waiting/{uid}`: the person's card, read by that person only: the list nearest to filling
  (the most entries, then the earliest deadline): seatId, barrio, pretext, slot, count,
  threshold, deadline, start, status (open | full | didntFill | joined), alternatives [one
  nearby ronda with places, as seguimos.alternatives writes it], choice?, updatedAt. Deleted
  once they wait nowhere. No other person's name or uid is in it: counts only.
"""

import logging
from datetime import date, datetime, timedelta

import demo_users
import rsvp
import seguimos

log = logging.getLogger(__name__)

OPEN, FULL, DIDNT_FILL, JOINED = "open", "full", "didntFill", "joined"
JOIN, WAIT = seguimos.JOIN, seguimos.WAIT
CHOICES = (JOIN, WAIT)
SUNDAY = 6


class WaitlistError(Exception):
    """A pick the callable refuses; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


# --- Rounds ---------------------------------------------------------------------------------


def first_round(today: date, slot_day: str) -> dict:
    """A new list's round: to the coming Sunday (today, on a Sunday), starting on the slot's day
    the week after."""
    deadline = today + timedelta(days=(SUNDAY - today.weekday()) % 7)
    return {"deadline": deadline.isoformat(), "start": start_after(deadline, slot_day).isoformat()}


def start_after(deadline: date, slot_day: str) -> date:
    """The slot's first day after `deadline`."""
    return rsvp.next_meeting(slot_day, deadline + timedelta(days=1))


def later(round_: dict, weeks: int) -> dict:
    """`round_` moved `weeks` weeks on."""
    return {
        key: (date.fromisoformat(round_[key]) + timedelta(weeks=weeks)).isoformat()
        for key in ("deadline", "start")
    }


# --- Who waits where --------------------------------------------------------------------------


def waiting_people(db) -> dict[str, dict]:
    """Every seat id someone waits for: its barrio, pretext and slot, and who waits (uid and
    when they signed up), longest waiting first."""
    from proposals import BARRIOS

    seated = set()
    for snapshot in db.collection("rondas").stream():
        if (snapshot.to_dict() or {}).get("status") not in rsvp.OPEN_STATUSES:
            continue
        for member in db.collection(f"rondas/{snapshot.id}/members").stream():
            if (member.to_dict() or {}).get("state") in ("active", "paused"):
                seated.add(member.id)
    lists: dict[str, dict] = {}
    for snapshot in db.collection("users").stream():
        uid, user = snapshot.id, snapshot.to_dict() or {}
        if uid in seated or not demo_users.counts(uid) or "firstName" not in user:
            continue
        barrio = user.get("barrio")
        if barrio not in BARRIOS:
            continue
        eligible = db.document(f"users/{uid}/private/eligible").get()
        seats = set((eligible.to_dict() or {}).get("seatIds", [])) if eligible.exists else set()
        for pretext in user.get("pretexts", []):
            for slot in user.get("slots", []):
                seat = f"{barrio}_{pretext}_{slot}"
                if seat in seats:
                    row = lists.setdefault(
                        seat, {"barrio": barrio, "pretext": pretext, "slot": slot, "entries": []}
                    )
                    row["entries"].append((uid, user.get("createdAt")))
    for row in lists.values():
        row["entries"].sort(key=lambda entry: (str(entry[1] or "~"), entry[0]))
    return lists


# --- The job ----------------------------------------------------------------------------------


def run_waitlists(db, now: datetime) -> dict:
    """Rebuilds every list and every waiting person's card; returns counts."""
    from ronda_solver.rules import size_rule

    today = rsvp.local(now).date()
    counts = {"lists": 0, "people": 0, "closed": 0, "didntFill": 0}
    lists = waiting_people(db)
    rows: dict[str, dict] = {}
    for snapshot in db.collection("waitlists").stream():
        if snapshot.id not in lists:
            db.document(f"waitlists/{snapshot.id}").delete()
    for seat, found in lists.items():
        entries, slot = found["entries"], found["slot"]
        threshold = size_rule(found["pretext"]).cap
        snapshot = db.document(f"waitlists/{seat}").get()
        current = (snapshot.to_dict() or {}) if snapshot.exists else {}
        round_ = current.get("round") or first_round(today, slot.split("-")[0])
        last, choices = current.get("last"), dict(current.get("choices", {}))
        if today > date.fromisoformat(round_["deadline"]):
            outcome = FULL if len(entries) >= threshold else DIDNT_FILL
            last = {**round_, "outcome": outcome, "closedAt": now}
            round_ = later(round_, 1 if outcome == FULL else seguimos.WAIT_WEEKS)
            choices = {}
            counts["closed"] += 1
            counts["didntFill"] += outcome == DIDNT_FILL
        row = {
            "barrio": found["barrio"],
            "pretext": found["pretext"],
            "slot": slot,
            "threshold": threshold,
            "entries": [{"uid": uid, "at": at} for uid, at in entries],
            "round": round_,
            "last": last,
            "choices": choices,
            "updatedAt": now,
        }
        db.document(f"waitlists/{seat}").set(row)
        rows[seat] = row
        counts["lists"] += 1
    nearby: dict[str, list[dict]] = {}
    cards = {}
    for seat, row in rows.items():
        for entry in row["entries"]:
            mine = cards.get(entry["uid"])
            if mine is None or _nearer(row, rows[mine]):
                cards[entry["uid"]] = seat
    for snapshot in db.collection("waiting").stream():
        if snapshot.id not in cards:
            db.document(f"waiting/{snapshot.id}").delete()
    for uid, seat in cards.items():
        row = rows[seat]
        if seat not in nearby:
            nearby[seat] = seguimos.alternatives(db, "", row, today)[:1]
        db.document(f"waiting/{uid}").set(card(seat, row, uid, nearby[seat], now))
        counts["people"] += 1
    log.info("waitlists: %s", counts)
    return counts


def _nearer(row: dict, other: dict) -> bool:
    """Whether list `row` is nearer to filling than `other`: more entries, then the earlier
    deadline."""
    return (-len(row["entries"]), row["round"]["deadline"]) < (
        -len(other["entries"]),
        other["round"]["deadline"],
    )


def card(seat: str, row: dict, uid: str, alternatives: list[dict], now: datetime) -> dict:
    """`waiting/{uid}`: the person's list, counts and dates, and what they may do now."""
    count, threshold = len(row["entries"]), row["threshold"]
    choice = row["choices"].get(uid)
    last = row.get("last") or {}
    if count >= threshold:
        status = FULL
    elif choice == JOIN:
        status = JOINED
    elif last.get("outcome") == DIDNT_FILL and choice is None:
        status = DIDNT_FILL
    else:
        status = OPEN
    fields = {
        "seatId": seat,
        "barrio": row["barrio"],
        "pretext": row["pretext"],
        "slot": row["slot"],
        "count": count,
        "threshold": threshold,
        "deadline": row["round"]["deadline"],
        "start": row["round"]["start"],
        "status": status,
        "alternatives": alternatives,
        "updatedAt": now,
    }
    if choice:
        fields["choice"] = choice
    return fields


# --- The pick ---------------------------------------------------------------------------------


def answer(db, uid: str, choice: object, now: datetime) -> dict:
    """Records `uid`'s pick after their list didn't fill: `join` (the nearby ronda on their
    card, which the admin then adds them to) or `wait` (the next round's dates). Only while
    their card asks it."""
    if choice not in CHOICES:
        raise WaitlistError("invalid-argument", "choice is join or wait")
    own_ref = db.document(f"waiting/{uid}")
    snapshot = own_ref.get()
    own = (snapshot.to_dict() or {}) if snapshot.exists else {}
    if own.get("status") != DIDNT_FILL:
        raise WaitlistError("failed-precondition", "there is nothing to choose")
    if choice == JOIN and not own.get("alternatives"):
        raise WaitlistError("failed-precondition", "there is no ronda nearby to join")
    batch = db.batch()
    batch.set(
        db.document(f"waitlists/{own['seatId']}"),
        {"choices": {uid: choice}, "updatedAt": now},
        merge=True,
    )
    batch.set(
        own_ref,
        {"choice": choice, "status": JOINED if choice == JOIN else OPEN, "updatedAt": now},
        merge=True,
    )
    batch.commit()
    return {"choice": choice, "start": own["start"], "deadline": own["deadline"]}
