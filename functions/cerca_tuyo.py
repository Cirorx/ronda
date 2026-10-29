"""Cerca tuyo and the tear-off flyer's landing: everything the public pages read.

`run_refresh_cerca(db, now)` rewrites one `cerca/{barrio}` per barrio: for each forming or
active ronda its pretext, slot, age range, taken seats, capacity and how many wait for it, and
per pretext how many neighbours wait for a ronda to start. Counts only: no uid, name or place
leaves this module. firestore.rules lets anyone `get` those documents and nothing else.

`landing(db, method, path, now)` answers the flyer's QR page through Hosting
(`/api/f/{id}`, firebase.json): a POST counts one scan on `flyers/{id}`, a GET only reads; both
return the rows of the barrios within walking distance of where the flyer hangs and the last bus
scripts/flyer.py stored when it made the flyer. The flyer's label is the admin's and stays in.
"""

import json
import re
from collections.abc import Callable, Iterable
from datetime import datetime

FLYER_ID = re.compile(r"[a-z0-9]{8}")
"""scripts/flyer.py's ids: eight lowercase letters and digits. Anything else is never read."""

OPEN_STATUSES = ("forming", "active")
"""A ronda Cerca shows: approved and not paused or ended."""

TAKING_A_SEAT = ("active", "paused")
"""A paused member's seat is held (docs/PRODUCT.md § The weekly loop); only leaving frees it."""

PRETEXTS = ("mate", "truco", "futbol5", "caminata")
DAYS = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")
BANDS = ("morning", "afternoon", "evening")

AGE_BANDS = {
    "18-29": (18, 29),
    "30-39": (30, 39),
    "40-49": (40, 49),
    "50-59": (50, 59),
    "60-69": (60, 69),
    "70-79": (70, 79),
    "80+": (80, None),
}

DAY_TYPES = ("weekday", "saturday", "sunday")
LAST_BUS_FIELDS = ("time", "estimated", "route", "published")


def run_refresh_cerca(db, now: datetime) -> int:
    """Rewrites every `cerca/{barrio}` from the rondas, their members and the sign-ups.

    Returns how many documents it wrote. The waiting counts come from sign-ups no ronda seats
    yet; once #28 writes `waitlists/{seatId}`, its entries should feed them too.
    """
    # Both import the solver package, and with it OR-Tools: only this job pays for that.
    from proposals import BARRIOS
    from ronda_solver.rules import size_rule

    users = {snapshot.id: snapshot.to_dict() for snapshot in db.collection("users").stream()}
    rondas = []
    for snapshot in db.collection("rondas").stream():
        ronda = snapshot.to_dict()
        if ronda.get("status") not in OPEN_STATUSES:
            continue
        members = [
            member.id
            for member in db.collection(f"rondas/{snapshot.id}/members").stream()
            if member.to_dict().get("state") in TAKING_A_SEAT
        ]
        rondas.append((ronda, members))
    documents = cerca_documents(BARRIOS, rondas, users, lambda p: size_rule(p).cap, now)
    batch = db.batch()
    for path, fields in documents.items():
        batch.set(db.document(path), fields)
    batch.commit()
    return len(documents)


def cerca_documents(
    barrios: Iterable[str],
    rondas: list[tuple[dict, list[str]]],
    users: dict[str, dict],
    cap: Callable[[str], int],
    now: datetime,
) -> dict[str, dict]:
    """`cerca/{barrio}` for every barrio, keyed by document path, from the open rondas (each
    with the uids taking a seat in it) and the `users/{uid}` documents.

    A neighbour waits when they saved a profile in a known barrio and no open ronda seats
    them. A ronda's `waiting` counts those who picked its barrio, pretext and slot; the
    barrio's `waiting` counts them by pretext. `cap(pretext)` is a ronda's most seats.
    """
    barrios = list(barrios)
    seated = {uid for _, members in rondas for uid in members}
    waiting = [
        user
        for uid, user in users.items()
        if "firstName" in user and user.get("barrio") in barrios and uid not in seated
    ]
    documents = {}
    for barrio in barrios:
        rows = [
            _ronda_row(ronda, members, users, waiting, cap)
            for ronda, members in rondas
            if ronda.get("barrio") == barrio
        ]
        rows.sort(key=lambda row: (_order(PRETEXTS, row["pretext"]), _slot_order(row["slot"])))
        counts = [
            {"pretext": pretext, "count": count}
            for pretext in PRETEXTS
            if (
                count := sum(
                    1
                    for user in waiting
                    if user["barrio"] == barrio and pretext in user.get("pretexts", [])
                )
            )
        ]
        documents[f"cerca/{barrio}"] = {
            "barrio": barrio,
            "rondas": rows,
            "waiting": counts,
            "updatedAt": now,
        }
    return documents


def _ronda_row(
    ronda: dict, members: list[str], users: dict[str, dict], waiting: list[dict], cap
) -> dict:
    pretext = ronda["pretext"]
    slot = f"{ronda['slot']['day']}-{ronda['slot']['time']}"
    bands = [AGE_BANDS[band] for uid in members if (band := users.get(uid, {}).get("ageBand"))]
    youngest = min(bands, key=lambda band: band[0], default=(None, None))
    oldest = max(bands, key=lambda band: band[0], default=(None, None))
    return {
        "pretext": pretext,
        "slot": slot,
        "ageFrom": youngest[0],
        "ageTo": oldest[1],
        "members": len(members),
        "cap": cap(pretext),
        "waiting": sum(
            1
            for user in waiting
            if user["barrio"] == ronda["barrio"]
            and pretext in user.get("pretexts", [])
            and slot in user.get("slots", [])
        ),
    }


def _order(values: tuple[str, ...], value: str) -> int:
    return values.index(value) if value in values else len(values)


def _slot_order(slot: str) -> tuple[int, int]:
    day, _, band = slot.partition("-")
    return _order(DAYS, day), _order(BANDS, band)


def landing(db, method: str, path: str, now: datetime) -> tuple[int, str]:
    """The status and JSON body for `/api/f/{id}`. A POST counts the scan; a GET doesn't."""
    if method not in ("GET", "POST"):
        return 405, json.dumps({"error": "method-not-allowed"})
    flyer_id = path.rstrip("/").rsplit("/", 1)[-1]
    if not FLYER_ID.fullmatch(flyer_id):
        return 404, json.dumps({"error": "not-found"})
    reference = db.document(f"flyers/{flyer_id}")
    snapshot = reference.get()
    if not snapshot.exists:
        return 404, json.dumps({"error": "not-found"})
    flyer = snapshot.to_dict()
    if method == "POST":
        from google.cloud.firestore import Increment

        reference.update({"scans": Increment(1), "lastScanAt": now})
    aggregates = {}
    for barrio in flyer.get("nearBarrios") or [flyer["barrio"]]:
        aggregate = db.document(f"cerca/{barrio}").get()
        if aggregate.exists:
            aggregates[barrio] = aggregate.to_dict()
    return 200, json.dumps(landing_body(flyer, aggregates))


def landing_body(flyer: dict, aggregates: dict[str, dict]) -> dict:
    """What `/f/{id}` shows: the nearby barrios' rows, each tagged with its barrio, the flyer's
    own barrio first, and the stop's last bus. Only the fields named here leave."""
    barrios = sorted(aggregates, key=lambda barrio: barrio != flyer["barrio"])
    updated = [aggregates[barrio]["updatedAt"] for barrio in barrios]
    stop = flyer.get("stop") or {}
    last_bus = flyer.get("lastBus") or {}
    return {
        "barrio": flyer["barrio"],
        "rondas": [
            {"barrio": barrio, **row} for barrio in barrios for row in aggregates[barrio]["rondas"]
        ],
        "waiting": [
            {"barrio": barrio, **count}
            for barrio in barrios
            for count in aggregates[barrio]["waiting"]
        ],
        "lastBus": {
            "stop": stop.get("name"),
            **{
                day_type: {key: bus[key] for key in LAST_BUS_FIELDS if key in bus}
                if (bus := last_bus.get(day_type))
                else None
                for day_type in DAY_TYPES
            },
        },
        "updatedAt": min(updated).isoformat() if updated else None,
    }
