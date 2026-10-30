"""Where, when and who: the admin sets each ronda's public place, its hour and its hosts
(docs/PRODUCT.md § The weekly loop, "Hosts"; #47).

`approve_proposal` writes a ronda with none of the three, and nothing invents them: until the
admin sets them the card says "Lugar y hora a confirmar", the RSVP push says the same, the rain
check reads the whole time band, and there is no host. Two admin callables back the screen at
`/admin/rondas`:

- `setups(db)` (`ronda_setups`): every ronda that still meets, with its place, hour and hosts,
  its members by first name (the admin can't read `users/` or a ronda's members from a client)
  and its latest attendance roll, for the admin who records it when no host can.
- `set_setup(db, data, now)` (`set_ronda_setup`): writes all three at once on
  `rondas/{id}`: `place {name, landmark?}`, `slot.hour` ("16:00", inside the band) and `hosts
  {anfitrion, cola, anfitrionName, colaName}`. An empty value removes it. The first names ride
  along so members' cards say "Abre Jorge y cierra Ana" without reading anyone's profile.

The place is the ronda's own, so it must be public: its words pass the organiser's word gates
(no emoji, voseo, nothing that looks like a home or an address), the same ones every message
naming it passes later. A home is only ever for the después.
"""

from datetime import datetime

import rsvp
from organiser import gates

NAME_LIMIT = 60
LANDMARK_LIMIT = 80
"""How long a place's name and its landmark ("al lado de la parada") may be."""

ROLES = ("anfitrion", "cola")


class SetupError(Exception):
    """A request the callables refuse; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def _place(ronda: dict) -> dict | None:
    if (name := rsvp.place_name(ronda)) is None:
        return None
    landmark = (ronda.get("place") or {}).get("landmark")
    return {"name": name, "landmark": landmark if isinstance(landmark, str) else ""}


def _hosts(ronda: dict) -> dict:
    hosts = ronda.get("hosts") or {}
    return {role: hosts.get(role) or "" for role in ROLES}


def _latest_roll(db, ronda_id: str) -> dict | None:
    rolls = {s.id: s.to_dict() or {} for s in db.collection(f"rondas/{ronda_id}/rolls").stream()}
    if not rolls:
        return None
    week = max(rolls)
    roll = rolls[week]
    return {
        "week": week,
        "date": roll.get("date", ""),
        "people": len(roll.get("people", [])),
        "marked": len(roll.get("marks", {})),
    }


def setups(db) -> list[dict]:
    """Every ronda that still meets, as the admin's screen shows it, by its line."""
    rows = []
    for snapshot in db.collection("rondas").stream():
        ronda = snapshot.to_dict()
        if ronda.get("status") not in rsvp.OPEN_STATUSES:
            continue
        members = rsvp.counted(rsvp._members(db, snapshot.id))
        names = rsvp._first_names(db, members)
        slot = ronda.get("slot") or {}
        rows.append(
            {
                "rondaId": snapshot.id,
                "line": rsvp.ronda_line(ronda),
                "pretext": ronda.get("pretext", ""),
                "barrio": ronda.get("barrio", ""),
                "slot": {"day": slot.get("day", ""), "time": slot.get("time", "")},
                "hour": rsvp.meeting_hour(ronda),
                "place": _place(ronda),
                "hosts": _hosts(ronda),
                "members": [
                    {"uid": uid, "firstName": names[uid]}
                    for uid in sorted(members, key=lambda u: (names[u], u))
                ],
                "roll": _latest_roll(db, snapshot.id),
            }
        )
    return sorted(rows, key=lambda row: (row["line"], row["rondaId"]))


def _text(value: object, field: str, limit: int, *, required: bool) -> str:
    if value is None:
        value = ""
    if not isinstance(value, str):
        raise SetupError("invalid-argument", f"{field} is a string")
    value = " ".join(value.split())
    if required and not value:
        raise SetupError("invalid-argument", f"{field} is required")
    if len(value) > limit:
        raise SetupError("invalid-argument", f"{field} is at most {limit} characters")
    if value and not (verdict := gates.check_words(value)).allowed:
        raise SetupError("failed-precondition", f"{field}: {verdict.reason}")
    return value


def _ronda_id(data: dict) -> str:
    ronda_id = data.get("rondaId")
    if not isinstance(ronda_id, str) or not ronda_id or "/" in ronda_id:
        raise SetupError("invalid-argument", "rondaId is required")
    return ronda_id


def set_setup(db, data: object, now: datetime) -> dict:
    """Sets ronda `rondaId`'s place, hour and hosts from `{rondaId, place: {name, landmark?} |
    null, hour: "16:00" | null, anfitrion: uid | "", cola: uid | ""}`; returns what it wrote.

    Refuses (`SetupError`) a place whose words look like a home or an address
    (`failed-precondition`), an hour outside the band, a host who isn't in the ronda, and the
    same person in both roles (`invalid-argument`).
    """
    from google.cloud.firestore import DELETE_FIELD

    data = data if isinstance(data, dict) else {}
    ronda_ref = db.document(f"rondas/{_ronda_id(data)}")
    snapshot = ronda_ref.get()
    if not snapshot.exists:
        raise SetupError("not-found", "no such ronda")
    ronda = snapshot.to_dict()

    place = data.get("place")
    if place is not None and not isinstance(place, dict):
        raise SetupError("invalid-argument", "place is an object or null")
    if place is not None:
        name = _text(place.get("name"), "place.name", NAME_LIMIT, required=True)
        landmark = _text(place.get("landmark"), "place.landmark", LANDMARK_LIMIT, required=False)
        place = {"name": name, "landmark": landmark} if landmark else {"name": name}

    slot = dict(ronda.get("slot") or {})
    hour = data.get("hour")
    if hour is not None and not rsvp.hour_in_band(hour, slot.get("time")):
        raise SetupError("invalid-argument", "hour is HH:MM inside the slot's band")

    members = rsvp.counted(rsvp._members(db, snapshot.id))
    chosen = {}
    for role in ROLES:
        uid = data.get(role) or ""
        if not isinstance(uid, str) or (uid and uid not in members):
            raise SetupError("invalid-argument", f"{role} is a member of the ronda")
        if uid:
            chosen[role] = uid
    if len(chosen) == 2 and chosen["anfitrion"] == chosen["cola"]:
        raise SetupError("invalid-argument", "the anfitrión and the cola are two people")
    names = rsvp._first_names(db, chosen.values())
    hosts = {**chosen, **{f"{role}Name": names[uid] for role, uid in chosen.items()}}

    if hour is None:
        slot.pop("hour", None)
    else:
        slot["hour"] = hour
    ronda_ref.update(
        {
            "place": place if place is not None else DELETE_FIELD,
            "slot": slot,
            "hosts": hosts if hosts else DELETE_FIELD,
            "setupAt": now,
        }
    )
    return {"rondaId": snapshot.id, "place": place, "hour": hour, "hosts": hosts}
