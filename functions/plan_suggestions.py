"""Three suggestions for Algo chico esta semana (docs/PRODUCT.md § Algo chico esta semana).

Code builds the candidates, so nothing the model says can be a place that doesn't exist or a
day that is closed or wet:
- `walk`: a plaza, park or rambla from the OSM cache (`free_places`), or "cerca de casa" when
  none is near; outdoors, so it gets a dry day;
- `feria`: a marketplace from the cache, only on a day its `opening_hours` say it is open
  (a marketplace with no hours is not offered: nothing says which day the feria is);
- `library`: a library, on a day its hours (if it has any) say it is open;
- `call`: calling someone the member hasn't talked to in a while, and `noPhone`: an afternoon
  without the phone. No place, any day.
Each gets a day and a time as `small_plans.choose_slot` does for a spoken plan.

Muse Spark Open (Baseten, falling back to Spark 1.3) picks three of them that fit the member's
pretexts and the week's weather, as a JSON list of ids; Baseten doesn't enforce a schema for
Spark Open, so the ids are validated here and anything unusable falls back to the rules: one
of each kind in the order walk, feria, library, call, noPhone. The model sees ids, kinds, place
names, days and a rain note: never a name, an address or anything personal about the member.
Nothing is stored; the callable keeps nothing.
"""

import json
import logging
import re
from dataclasses import dataclass
from datetime import date, datetime, time
from typing import Any

import free_places
import opening_hours
import small_plans
from organiser.model import ModelClient, ModelUnavailable
from organiser.weather import Day

log = logging.getLogger(__name__)

COUNT = 3
ORDER = ["walk", "feria", "library", "call", "noPhone"]
PER_KIND = 2
"""At most this many candidates of a kind: the nearest places."""
PLACE_KINDS = {
    "walk": (free_places.PROMENADE, free_places.PARK),
    "feria": (free_places.MARKETPLACE,),
    "library": (free_places.LIBRARY,),
}
OUTDOORS = {"walk": True, "feria": True}
HOURS_REQUIRED = {"feria"}
PRETEXT_LABELS = {
    "mate": "mate en la rambla",
    "truco": "truco",
    "futbol5": "fútbol 5",
    "caminata": "caminata",
    "conga": "conga",
    "merienda": "café o merienda",
    "pajaros": "mirar pájaros",
}

INSTRUCTIONS = """Sos el que elige ideas de Ronda: grupos semanales de vecinos. Una persona
quiere proponerse algo chico para esta semana, y tenés una lista de ideas posibles, cada una
con su id, tipo, lugar, día y la lluvia prevista. Elegí tres ideas distintas que le queden bien
a lo que le gusta hacer (lo que hace en su ronda) y al clima de la semana: preferí lo que la
saca de casa hacia lugares con gente. Respondé solo un JSON como {"ids": ["walk-1", "call-1",
"library-1"]}, con tres ids de la lista, sin repetir y sin texto aparte."""


@dataclass(frozen=True)
class Candidate:
    """One suggestion with its day: a place for the kinds that have one."""

    id: str
    kind: str
    place: free_places.Place | None
    slot: small_plans.Slot
    outdoor: bool


def candidates(
    places: list[free_places.Place], *, now: datetime, week: dict[date, Day]
) -> list[Candidate]:
    """Every suggestion that can happen in the next week, nearest places first. `walk`, `call`
    and `noPhone` always have one."""
    found: list[Candidate] = []
    for kind in ORDER:
        count = 0
        for place in (p for p in places if p.kind in PLACE_KINDS.get(kind, ())):
            if count == PER_KIND:
                break
            if kind in HOURS_REQUIRED and not place.hours:
                continue
            if (slot := _slot(kind, place, now, week)) is not None:
                count += 1
                found.append(
                    Candidate(f"{kind}-{count}", kind, place, slot, OUTDOORS.get(kind, False))
                )
        if (
            count == 0
            and kind in ("walk", "call", "noPhone")
            and (slot := _slot(kind, None, now, week)) is not None
        ):
            found.append(Candidate(f"{kind}-1", kind, None, slot, OUTDOORS.get(kind, False)))
    return found


def _slot(
    kind: str, place: free_places.Place | None, now: datetime, week: dict[date, Day]
) -> small_plans.Slot | None:
    at = small_plans.DEFAULT_TIMES[kind]
    days = [
        day
        for day in small_plans.candidate_days(now, at)
        if place is None or _open(place, day, at, week)
    ]
    return small_plans.choose_slot(
        days, at, named=None, outdoor=OUTDOORS.get(kind, False), week=week
    )


def _open(place: free_places.Place, day: date, at: time, week: dict[date, Day]) -> bool:
    sunset = week[day].sunset if day in week else "19:00"
    return opening_hours.open_at(place.hours, day, at, sunset)


def describe(candidate: Candidate, week: dict[date, Day]) -> dict[str, Any]:
    """What the model reads about a candidate."""
    rain = small_plans.rain_at(week, candidate.slot.on, candidate.slot.at)
    return {
        "id": candidate.id,
        "kind": candidate.kind,
        "place": candidate.place.name if candidate.place else None,
        "day": small_plans.WEEKDAYS[candidate.slot.on.weekday()],
        "rainProbability": rain,
    }


def wire(candidate: Candidate) -> dict[str, Any]:
    """A suggestion as the app reads it: the app writes the sentence for its `kind` and
    `place`, in the phone's language."""
    return {
        "id": candidate.id,
        "kind": candidate.kind,
        "place": candidate.place.name if candidate.place else None,
        "date": candidate.slot.on.isoformat(),
        "time": candidate.slot.at.strftime("%H:%M"),
        "outdoor": candidate.outdoor,
        "dry": candidate.slot.dry,
    }


def by_rules(found: list[Candidate]) -> list[Candidate]:
    """One of each kind in `ORDER`, then more of the kinds that have them."""
    chosen = [
        first for kind in ORDER if (first := next((c for c in found if c.kind == kind), None))
    ]
    chosen += [c for c in found if c not in chosen]
    return chosen[:COUNT]


def by_model(
    found: list[Candidate], pretexts: list[str], week: dict[date, Day], model: ModelClient
) -> list[Candidate]:
    """The model's three, validated: its ids that exist, once each, in its order, filled up by
    the rules. Raises `ModelUnavailable` when it fails or answers nothing usable."""
    liked = [PRETEXT_LABELS[p] for p in pretexts if p in PRETEXT_LABELS]
    request = json.dumps(
        {"leGusta": liked, "ideas": [describe(c, week) for c in found]}, ensure_ascii=False
    )
    turn = model.complete(
        [{"role": "system", "content": INSTRUCTIONS}, {"role": "user", "content": request}], []
    )
    ids = parse_ids(turn.content)
    by_id = {c.id: c for c in found}
    picked = [by_id[i] for i in dict.fromkeys(ids) if i in by_id]
    if not picked:
        raise ModelUnavailable("no usable ids")
    picked = picked[:COUNT]
    return picked + [c for c in by_rules(found) if c not in picked][: COUNT - len(picked)]


_JSON = re.compile(r"\{.*\}", re.DOTALL)


def parse_ids(content: str) -> list[str]:
    """The `ids` of the JSON object in the model's answer; empty when there is none. Spark Open
    answers in Markdown, and wraps the JSON in a fence."""
    match = _JSON.search(strip_markdown_fence(content))
    if match is None:
        return []
    try:
        ids = json.loads(match.group()).get("ids")
    except (ValueError, AttributeError):
        return []
    return [i for i in ids if isinstance(i, str)] if isinstance(ids, list) else []


def strip_markdown_fence(content: str) -> str:
    """The answer with a Markdown code fence taken off, keeping its line breaks."""
    return re.sub(r"```[a-z]*", "", content)


def suggest(
    *,
    user: dict[str, Any] | None,
    places: list[free_places.Place],
    now: datetime,
    weather: small_plans.Forecast,
    model: ModelClient | None,
) -> dict[str, Any]:
    """The `suggest_small_plans` callable's answer: `{"suggestions": [three], "pickedBy":
    "model" | "rules"}`. With no `model`, or when it fails, the rules pick."""
    user = user or {}
    week = small_plans.forecast_week(weather, user.get("barrio"), now)
    found = candidates(places, now=now, week=week)
    picked, by = by_rules(found), "rules"
    if model is not None:
        pretexts = [p for p in user.get("pretexts") or [] if isinstance(p, str)]
        try:
            picked, by = by_model(found, pretexts, week, model), "model"
        except ModelUnavailable as error:
            log.warning("suggestions: model failed (%s); the rules pick", error)
    return {"suggestions": [wire(c) for c in picked], "pickedBy": by}
