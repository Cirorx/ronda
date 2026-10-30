"""The pilot's numbers on /admin, each as "x of y", read with the admin's rights by the
`pilot_numbers` callable (nothing is stored; members never see any of it).

`numbers(db, now)` counts only sign-ups that count here (demo_users.counts): on the real project
the invented `demo-` people are left out of every number, and a ronda with no member who counts
is left out whole, as Cerca does.

- `signUps`: `users/{uid}` documents (the terms accepted) and how many of them saved a profile.
- `seated`: of those with a profile, how many sit in a ronda that still meets.
- `rondas`: each ronda with a member who counts, by its line: status, members sitting and the
  pretext's cap, and per week (`rondas/{id}/weeks/{isoWeek}`, by week id):
  - the RSVP as members read it (`rsvp.week_view`: voy / no puede / sin contestar, a member
    paused over the meeting counts as no puede) among the members that week: joined by the
    meeting's date and not left before it;
  - attendance from `attendance {uid: bool}` (written by the host's "¿Quién vino hoy?"): how
    many came of how many the host marked, `null` while unmarked;
  - `cameBack`: of those who came to the ronda's first marked meeting, how many came to the
    next marked one; `null` until two meetings are marked;
  - `seguimos`: the ronda's `seguimos_counts/{id}` (sí / no / sin contestar of those asked).
- `cameBack`: the same, over every ronda.

Everything returned is JSON: ids, counts and ISO dates, never a name or a uid.
"""

from datetime import date, datetime

import demo_users
import rsvp
from ronda_members import cap, seated


def _local_date(value) -> date | None:
    return rsvp.local(value).date() if isinstance(value, datetime) else None


def week_members(members: dict[str, dict], meeting: date | None) -> dict[str, dict]:
    """The members a week counts: joined by `meeting` and not left before it; one who left
    afterwards counts as in. Without a date, everyone still in."""
    if meeting is None:
        return rsvp.counted(members)
    found = {}
    for uid, member in members.items():
        joined, left = _local_date(member.get("joinedAt")), _local_date(member.get("leftAt"))
        if joined is not None and joined > meeting:
            continue
        if member.get("state") == "left":
            if left is None or left < meeting:
                continue
            member = {**member, "state": "active"}
        found[uid] = member
    return found


def week_numbers(week_id: str, week: dict, members: dict[str, dict], now: datetime) -> dict:
    """One week of one ronda: the RSVP and the attendance, counting members who count only."""
    meeting = date.fromisoformat(week["date"]) if week.get("date") else None
    those = week_members(members, meeting)
    answers = {uid: value for uid, value in week.get("rsvp", {}).items() if uid in those}
    view = rsvp.week_view(meeting or rsvp.local(now).date(), those, {}, answers, now)
    attendance = week.get("attendance")
    marked = (
        {uid: came for uid, came in attendance.items() if demo_users.counts(uid)}
        if isinstance(attendance, dict)
        else None
    )
    return {
        "week": week_id,
        "date": week.get("date"),
        "members": len(rsvp.counted(those)),
        "yes": len(view["going"]),
        "no": view["noCount"],
        "unanswered": view["unansweredCount"],
        "came": None if marked is None else sum(1 for came in marked.values() if came is True),
        "marked": None if marked is None else len(marked),
    }


def came_back(weeks: list[dict]) -> dict | None:
    """Of who came to the first marked meeting, how many came to the next marked one; `weeks`
    are week documents in order."""
    marked = [w["attendance"] for w in weeks if isinstance(w.get("attendance"), dict)]
    if len(marked) < 2:
        return None
    first = {uid for uid, came in marked[0].items() if came is True and demo_users.counts(uid)}
    again = {uid for uid, came in marked[1].items() if came is True}
    return {"came": len(first & again), "of": len(first)}


def numbers(db, now: datetime) -> dict:
    """The panel's numbers (see the module's docstring)."""
    users = {
        s.id: s.to_dict() or {} for s in db.collection("users").stream() if demo_users.counts(s.id)
    }
    profiles = {uid for uid, user in users.items() if "firstName" in user}
    sitting: set[str] = set()
    rondas = []
    back = {"came": 0, "of": 0}
    any_back = False
    for snapshot in db.collection("rondas").stream():
        ronda_id, ronda = snapshot.id, snapshot.to_dict() or {}
        members = {
            uid: member
            for uid, member in rsvp._members(db, ronda_id).items()
            if demo_users.counts(uid)
        }
        if not members:
            continue
        inside = seated(members)
        if ronda.get("status") in rsvp.OPEN_STATUSES:
            sitting |= set(inside)
        weeks = sorted(
            (s.id, s.to_dict() or {}) for s in db.collection(f"rondas/{ronda_id}/weeks").stream()
        )
        returned = came_back([week for _, week in weeks])
        if returned is not None:
            any_back = True
            back = {key: back[key] + returned[key] for key in back}
        counts = db.document(f"seguimos_counts/{ronda_id}").get()
        seguimos = None
        if counts.exists:
            row = counts.to_dict() or {}
            seguimos = {key: row.get(key, 0) for key in ("asked", "yes", "no", "unanswered")}
            seguimos["status"] = row.get("status", "open")
        rondas.append(
            {
                "rondaId": ronda_id,
                "line": rsvp.ronda_line(ronda),
                "status": ronda.get("status", ""),
                "members": len(inside),
                "cap": cap(ronda),
                "weeks": [week_numbers(week_id, week, members, now) for week_id, week in weeks],
                "cameBack": returned,
                "seguimos": seguimos,
            }
        )
    rondas.sort(key=lambda r: (r["line"], r["rondaId"]))
    return {
        "signUps": {"profiles": len(profiles), "of": len(users)},
        "seated": {"members": len(sitting & profiles), "of": len(profiles)},
        "rondas": rondas,
        "cameBack": back if any_back else None,
    }
