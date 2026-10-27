"""Invented demo neighbours for the bench and the fixtures. No real people.

Barrio names are real places in Ciudad de la Costa, split north and south of Avenida
Giannattasio for the demo; their centroids are approximate and invented for it.
"""

import random

from ronda_solver.problem import seat_id

DEMO_NOTE = (
    "Invented demo data: no real people. Barrio names are real places in Ciudad de la Costa "
    "with approximate, invented centroids."
)

DEMO_BARRIOS = {
    "shangrila": (-34.8660, -55.9930),
    "san-jose-de-carrasco": (-34.8560, -55.9760),
    "lagomar-sur": (-34.8420, -55.9620),
    "lagomar-norte": (-34.8345, -55.9665),
    "solymar-sur": (-34.8330, -55.9380),
    "solymar-norte": (-34.8255, -55.9420),
    "lomas-de-solymar": (-34.8150, -55.9450),
    "el-pinar-sur": (-34.8000, -55.8850),
    "el-pinar-norte": (-34.7925, -55.8890),
}
_BARRIO_WEIGHTS = [3, 3, 10, 10, 30, 30, 4, 5, 5]

_PRETEXTS = {"mate": 45, "caminata": 25, "truco": 18, "futbol5": 12}
_SLOTS = {"sat-afternoon": 30, "sun-afternoon": 25, "sat-morning": 15, "thu-evening": 15}
_AGE_BANDS = {
    "18-29": 15,
    "30-39": 10,
    "40-49": 10,
    "50-59": 12,
    "60-69": 25,
    "70-79": 20,
    "80+": 8,
}


def _pick(rng: random.Random, weighted: dict[str, int], k: int) -> list[str]:
    chosen: list[str] = []
    while len(chosen) < k:
        [item] = rng.choices(list(weighted), weights=list(weighted.values()))
        if item not in chosen:
            chosen.append(item)
    return sorted(chosen)


def _neighbour(rng: random.Random, uid: str) -> dict:
    [barrio] = rng.choices(list(DEMO_BARRIOS), weights=_BARRIO_WEIGHTS)
    pretexts = _pick(rng, _PRETEXTS, rng.choice([1, 1, 2]))
    slots = _pick(rng, _SLOTS, rng.choice([2, 2, 3]))
    seats = [seat_id(b, p, s) for b in DEMO_BARRIOS for p in pretexts for s in slots]
    if rng.random() < 0.2:  # stands in for the phone's needs filter, which drops some seats
        seats = [s for s in seats if rng.random() > 0.3]
    return {
        "uid": uid,
        "ageBand": _pick(rng, _AGE_BANDS, 1)[0],
        "barrio": barrio,
        "pretexts": pretexts,
        "slots": slots,
        "eligibleSeatIds": seats,
    }


def invented_problem(people: int, seed: int = 23) -> dict:
    """`people` invented neighbours: about one in ten brings a +1, and a few report-apart pairs."""
    rng = random.Random(seed)
    neighbours: list[dict] = []
    while len(neighbours) < people:
        neighbour = _neighbour(rng, f"demo-{len(neighbours) + 1:03}")
        neighbours.append(neighbour)
        if len(neighbours) < people and rng.random() < 0.1:
            plus_one = {
                **neighbour,
                "uid": f"demo-{len(neighbours) + 1:03}",
                "ageBand": _pick(rng, _AGE_BANDS, 1)[0],
            }
            neighbour["plusOneUid"] = plus_one["uid"]
            neighbours.append(plus_one)
    uids = [n["uid"] for n in neighbours]
    avoid = [sorted(rng.sample(uids, 2)) for _ in range(max(1, people // 60))]
    return {
        "_note": DEMO_NOTE,
        "barrios": {b: {"lat": lat, "lng": lng} for b, (lat, lng) in DEMO_BARRIOS.items()},
        "people": neighbours,
        "avoidPairs": avoid,
    }
