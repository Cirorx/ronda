"""The solver's input, parsed from JSON into immutable records."""

from dataclasses import dataclass, field
from functools import cached_property
from itertools import product

from ronda_solver.geo import blocks_between
from ronda_solver.rules import WEIGHTS, SoftRule

MAX_TIME_IN_SECONDS = 8.0
ALTERNATIVE_TIME_IN_SECONDS = 2.0


def seat_id(barrio: str, pretext: str, slot: str) -> str:
    """The id of every seat in the candidate ronda barrio × pretext × slot (the waitlist key)."""
    return f"{barrio}_{pretext}_{slot}"


@dataclass(frozen=True)
class Person:
    uid: str
    age_band: str
    barrio: str
    pretexts: frozenset[str]
    slots: frozenset[str]
    eligible_seat_ids: frozenset[str]
    plus_one_uid: str | None = None


@dataclass(frozen=True)
class Candidate:
    """A ronda that could open: one per barrio × pretext × slot, so groups have no symmetry."""

    barrio: str
    pretext: str
    slot: str

    @property
    def id(self) -> str:
        return seat_id(self.barrio, self.pretext, self.slot)


@dataclass(frozen=True)
class Options:
    max_time_in_seconds: float = MAX_TIME_IN_SECONDS
    alternative_time_in_seconds: float = ALTERNATIVE_TIME_IN_SECONDS
    weights: dict[SoftRule, int] = field(default_factory=lambda: dict(WEIGHTS))


@dataclass(frozen=True)
class Problem:
    barrios: dict[str, tuple[float, float]]
    people: tuple[Person, ...]
    avoid_pairs: tuple[tuple[str, str], ...] = ()
    options: Options = field(default_factory=Options)

    @property
    def weights(self) -> dict[SoftRule, int]:
        return self.options.weights

    def blocks(self, from_barrio: str, to_barrio: str) -> float:
        return self._blocks[from_barrio, to_barrio]

    def walk(self, person: Person, candidate: Candidate) -> int:
        """Whole blocks from the person's barrio centroid to the ronda's."""
        return round(self.blocks(person.barrio, candidate.barrio))

    def person(self, uid: str) -> Person:
        return self._by_uid[uid]

    def has_person(self, uid: str) -> bool:
        return uid in self._by_uid

    @cached_property
    def plus_one_pairs(self) -> list[tuple[str, str]]:
        """Each +1 pair once, in uid order; a +1 who has not signed up yet makes no pair."""
        return sorted(
            {
                (min(p.uid, p.plus_one_uid), max(p.uid, p.plus_one_uid))
                for p in self.people
                if p.plus_one_uid in self._by_uid and p.plus_one_uid != p.uid
            }
        )

    @cached_property
    def candidates(self) -> list[Candidate]:
        """barrio × pretext × slot over every barrio, pretext and slot in the input."""
        pretexts = sorted({p for person in self.people for p in person.pretexts})
        slots = sorted({s for person in self.people for s in person.slots})
        return [Candidate(*key) for key in product(sorted(self.barrios), pretexts, slots)]

    @cached_property
    def _by_uid(self) -> dict[str, Person]:
        return {p.uid: p for p in self.people}

    @cached_property
    def _blocks(self) -> dict[tuple[str, str], float]:
        return {
            (a, b): blocks_between(self.barrios[a], self.barrios[b])
            for a, b in product(self.barrios, repeat=2)
        }


def _parse_person(p: dict) -> Person:
    return Person(
        uid=p["uid"],
        age_band=p["ageBand"],
        barrio=p["barrio"],
        pretexts=frozenset(p["pretexts"]),
        slots=frozenset(p["slots"]),
        eligible_seat_ids=frozenset(p["eligibleSeatIds"]),
        plus_one_uid=p.get("plusOneUid"),
    )


def _parse_options(data: dict) -> Options:
    weights = dict(WEIGHTS)
    for name, weight in data.get("weights", {}).items():
        if name not in SoftRule:
            raise ValueError(f"unknown soft rule in options.weights: {name!r}")
        weights[SoftRule(name)] = int(weight)
    return Options(
        max_time_in_seconds=data.get("maxTimeInSeconds", MAX_TIME_IN_SECONDS),
        alternative_time_in_seconds=data.get(
            "alternativeTimeInSeconds", ALTERNATIVE_TIME_IN_SECONDS
        ),
        weights=weights,
    )


def parse_problem(data: dict) -> Problem:
    """Reads the input contract (solver/README.md). Raises ValueError on inconsistent input."""
    barrios = {name: (c["lat"], c["lng"]) for name, c in data["barrios"].items()}
    people = tuple(_parse_person(p) for p in data["people"])
    seen = set()
    for person in people:
        if person.uid in seen:
            raise ValueError(f"uid {person.uid!r} appears twice")
        seen.add(person.uid)
        if person.barrio not in barrios:
            raise ValueError(f"{person.uid!r} is in barrio {person.barrio!r}, not in barrios")
    ids = {*barrios, *(i for p in people for i in (*p.pretexts, *p.slots))}
    if joined := sorted(i for i in ids if "_" in i):
        raise ValueError(f"{joined[0]!r}: ids must not contain '_', which joins seat ids")
    avoid_pairs = tuple((a, b) for a, b in data.get("avoidPairs", []))
    return Problem(
        barrios=barrios,
        people=people,
        avoid_pairs=avoid_pairs,
        options=_parse_options(data.get("options", {})),
    )
