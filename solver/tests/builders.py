"""Builders for invented test problems. Every uid and record here is invented demo data."""

from itertools import product

# Approximate centroids, invented for tests: SOLYMAR_* are ~9 blocks apart, EL_PINAR is far.
BARRIOS = {
    "solymar-sur": {"lat": -34.8330, "lng": -55.9380},
    "solymar-norte": {"lat": -34.8255, "lng": -55.9420},
    "el-pinar-sur": {"lat": -34.8000, "lng": -55.8850},
}


def seat_ids(barrios, pretexts, slots):
    return [f"{b}_{p}_{s}" for b, p, s in product(barrios, pretexts, slots)]


def person(
    uid,
    *,
    age_band="60-69",
    barrio="solymar-sur",
    pretexts=("mate",),
    slots=("sat-afternoon",),
    eligible=None,
    plus_one=None,
):
    record = {
        "uid": uid,
        "ageBand": age_band,
        "barrio": barrio,
        "pretexts": list(pretexts),
        "slots": list(slots),
        "eligibleSeatIds": (
            list(eligible) if eligible is not None else seat_ids(BARRIOS, pretexts, slots)
        ),
    }
    if plus_one is not None:
        record["plusOneUid"] = plus_one
    return record


def problem(people, *, avoid=(), barrios=None, options=None):
    data = {
        "barrios": barrios if barrios is not None else BARRIOS,
        "people": list(people),
        "avoidPairs": [list(pair) for pair in avoid],
    }
    if options is not None:
        data["options"] = options
    return data


def ronda(uids, *, barrio="solymar-sur", pretext="mate", slot="sat-afternoon"):
    """A hand-built proposed ronda: its key and its members' uids."""
    return {
        "id": f"{barrio}_{pretext}_{slot}",
        "barrio": barrio,
        "pretext": pretext,
        "slot": slot,
        "members": [{"uid": uid} for uid in uids],
    }


def grouping(data, *rondas):
    """A hand-built result: these rondas, and everyone else unseated."""
    seated = {m["uid"] for r in rondas for m in r["members"]}
    return {
        "proposals": list(rondas),
        "unseated": [p["uid"] for p in data["people"] if p["uid"] not in seated],
    }


def members_of(result):
    """Sorted member uids of each proposed ronda, keyed by ronda id."""
    return {r["id"]: sorted(m["uid"] for m in r["members"]) for r in result["proposals"]}
