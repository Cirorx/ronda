"""Ronda's invented demo data as Firestore documents: no real people, places or seats.

The people come from the solver's generator (`ronda_solver.demo`, fixed seed), so the 30-person
set is exactly `solver/fixtures/invented_demo_30.json`. This module adds what the app shows and
the generator leaves out (first names, brings), deterministically, and lays everything out
in the shape `docs/ARCHITECTURE.md` § Data model and `firestore.rules` expect. Every seeded uid
starts with `demo-`: the rules' field allowlist leaves no room for a label field, so the id is the
label.

`documents(people)` is the whole state, keyed by document path. To seed another collection, write
a builder `(problem) -> {path: fields}` and add it to `BUILDERS`.
"""

import json
import random
import sys
from collections.abc import Callable
from datetime import UTC, datetime
from itertools import product
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INVENTED_SEAT_FACTS = ROOT / "data" / "demo" / "invented_seat_facts.json"

# ronda_solver is not an installable package (solver/pyproject.toml: package = false), so the
# generator is imported from its folder.
sys.path.append(str(ROOT / "solver"))
from ronda_solver.demo import DEMO_BARRIOS, invented_problem  # noqa: E402
from ronda_solver.geo import blocks_between  # noqa: E402

SET_SIZES = (30, 200)
"""The invented sign-up sets: 30 for the golden path and the solver's tests, 200 for scale."""

DEMO_TIME = datetime(2026, 10, 27, 15, 0, tzinfo=UTC)
"""Invented: the one moment (2026-10-27 12:00 in Uruguay) every seeded timestamp carries, so two
seeds write identical documents. Never a server timestamp."""

TERMS_VERSION = "2026-10-27"
"""The conditions every demo sign-up accepted: the app's `AppBloc.termsVersion`."""

# The app's ids in its enums' declaration order (packages/profile_repository/lib/src/models/),
# which is the order ProfileRepository stores lists in.
PRETEXTS = ("mate", "truco", "futbol5", "caminata")
SLOT_DAYS = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")
SLOT_BANDS = ("morning", "afternoon", "evening")
BRINGS = ("pan", "yerba", "termo", "sillas", "enseno-truco", "tengo-ganas")

# Invented first names, common in Uruguay, by generation. Assigned in turn, so the 30 set
# repeats none.
FIRST_NAMES_UNDER_50 = (
    "Sofía", "Matías", "Lucía", "Martín", "Valentina", "Nicolás", "Camila", "Federico",
    "Florencia", "Agustín", "Micaela", "Santiago", "Romina", "Diego", "Carolina", "Pablo",
    "Natalia", "Gonzalo", "Paula", "Andrés",
)  # fmt: skip
FIRST_NAMES_50_AND_OVER = (
    "Marta", "Raúl", "Graciela", "Jorge", "Beatriz", "Hugo", "Nelly", "Walter", "Mirta",
    "Washington", "Elsa", "Rubén", "Teresa", "Omar", "Susana", "Julio", "Gladys", "Héctor",
    "Olga", "Néstor", "Alba", "Carlos", "Rosa", "Luis", "Elena", "Daniel", "Silvia", "Alberto",
)  # fmt: skip
UNDER_50 = {"18-29", "30-39", "40-49"}

Documents = dict[str, dict]
Builder = Callable[[dict], Documents]


def documents(people: int) -> Documents:
    """The demo state for `people` invented sign-ups (30 or 200), keyed by document path."""
    if people not in SET_SIZES:
        raise ValueError(f"people must be one of {SET_SIZES}, not {people}")
    problem = invented_problem(people)
    state: Documents = {}
    for build in BUILDERS:
        state |= build(problem)
    return state


def seat_facts_documents(problem: dict) -> Documents:
    """`seat_facts/{seatId}` for every barrio × pretext × slot the demo people pick.

    The hand-made seats in data/demo/invented_seat_facts.json replace their generated twins,
    which keeps the two places an invented host has set.
    """
    pretexts = sorted({p for person in problem["people"] for p in person["pretexts"]})
    slots = sorted({s for person in problem["people"] for s in person["slots"]})
    seats = generated_seat_facts(pretexts, slots)
    seats |= json.loads(INVENTED_SEAT_FACTS.read_text())["seats"]
    return {
        f"seat_facts/{seat_id}": {**facts, "updatedAt": DEMO_TIME}
        for seat_id, facts in sorted(seats.items())
    }


def generated_seat_facts(pretexts: list[str], slots: list[str]) -> dict[str, dict]:
    """Facts for every demo barrio × `pretexts` × `slots`, by seat id, the way
    data/demo/invented_seat_facts.json was made: `blocksFrom` is the haversine walk in blocks from
    each barrio's centroid to the seat's, rounded to 0.1; evening slots end after dark; no host
    has set a place yet, so no stairs and no car."""
    return {
        f"{barrio}_{pretext}_{slot}": {
            "barrio": barrio,
            "pretext": pretext,
            "slot": slot,
            "blocksFrom": {
                origin: round(blocks_between(centroid, DEMO_BARRIOS[barrio]), 1)
                for origin, centroid in DEMO_BARRIOS.items()
            },
            "hasStairs": False,
            "endsAfterDark": slot.endswith("-evening"),
            "needsCar": False,
        }
        for barrio, pretext, slot in product(DEMO_BARRIOS, pretexts, slots)
    }


def user_documents(problem: dict) -> Documents:
    """`users/{uid}`: the profile and accepted terms the app writes at onboarding."""
    names = _first_names(problem["people"])
    return {
        f"users/{person['uid']}": {
            "firstName": names[person["uid"]],
            "ageBand": person["ageBand"],
            "barrio": person["barrio"],
            "slots": _in_order(person["slots"], _SLOT_ORDER),
            "pretexts": _in_order(person["pretexts"], PRETEXTS),
            "brings": _brings(person),
            **({"plusOneUid": person["plusOneUid"]} if "plusOneUid" in person else {}),
            "terms": {"version": TERMS_VERSION, "acceptedAt": DEMO_TIME},
            "createdAt": DEMO_TIME,
        }
        for person in problem["people"]
    }


def eligible_documents(problem: dict) -> Documents:
    """`users/{uid}/private/eligible`: exactly the seat ids and when. Needs are never written."""
    return {
        f"users/{person['uid']}/private/eligible": {
            "seatIds": person["eligibleSeatIds"],
            "updatedAt": DEMO_TIME,
        }
        for person in problem["people"]
    }


def avoid_documents(problem: dict) -> Documents:
    """`avoid/{uidA}_{uidB}`: each report-apart pair once, in uid order."""
    return {
        f"avoid/{uid_a}_{uid_b}": {"uidA": uid_a, "uidB": uid_b}
        for uid_a, uid_b in sorted(tuple(sorted(pair)) for pair in problem["avoidPairs"])
    }


BUILDERS: tuple[Builder, ...] = (
    seat_facts_documents,
    user_documents,
    eligible_documents,
    avoid_documents,
)

_SLOT_ORDER = tuple(f"{day}-{band}" for day in SLOT_DAYS for band in SLOT_BANDS)


def _in_order(ids: list[str], order: tuple[str, ...]) -> list[str]:
    return sorted(ids, key=order.index)


def _first_names(people: list[dict]) -> dict[str, str]:
    """Each generation's names in turn, in the generator's order, so the 200 set's first 30
    people keep the names they have in the 30 set."""
    turns = {False: 0, True: 0}
    names = {}
    for person in people:
        younger = person["ageBand"] in UNDER_50
        pool = FIRST_NAMES_UNDER_50 if younger else FIRST_NAMES_50_AND_OVER
        names[person["uid"]] = pool[turns[younger] % len(pool)]
        turns[younger] += 1
    return names


def _brings(person: dict) -> list[str]:
    """One or two things to bring, seeded by uid; some just come ("tengo ganas")."""
    rng = random.Random(f"brings-{person['uid']}")
    if rng.random() < 0.15:
        return ["tengo-ganas"]
    brings = set(rng.sample(["pan", "yerba", "termo", "sillas"], rng.choice([1, 1, 2])))
    if "truco" in person["pretexts"] and rng.random() < 0.5:
        brings.add("enseno-truco")
    return _in_order(list(brings), BRINGS)
