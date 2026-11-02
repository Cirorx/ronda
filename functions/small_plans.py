"""Algo chico esta semana: what a member says (or types) becomes one small dated plan
(docs/PRODUCT.md § Algo chico esta semana).

`shape_request` is the whole of the `shape_small_plan` callable except Firebase: the words
(typed, or a voice note read by Voice Transcribe, then deleted), a pre-check of those words,
Spark 1.3 filling the strict `Draft`, the filter below, and Open-Meteo choosing the day.

**The filter** (`filter_plan`, in code, whatever the model says) keeps a plan to `{activity,
day, time, place}` and drops it, with a reason, when it is about:
- `health`: a health or medical goal, exercise as treatment, wellbeing;
- `diet`: a diet, weight, calories;
- `money`: anything that mentions it (`organiser.text.money`, plus buying and saving);
- `people`: anyone else, by name or by relationship ("mi hija", "con Ana");
- `unclear`: nothing usable, or words the gates refuse (emoji, tú forms, a home or address).
The model also fills a `flag` with the same four topics; either one drops the plan. Its words
are checked, and so are the member's own. Each check is a plain word list with known limits
(it catches the frequent phrasings, not every one); the word lists are in this file.

**The day** (`schedule`): plans are for the next seven days. A plan outdoors gets a dry day by
Open-Meteo (rain probability under 40 % and under 0.5 mm in the plan's two hours): the day the
member named if it is dry, else the nearest dry day (`moved`), and with none, the day with the
least rain (`dry: false`). With no day named, the earliest dry day. Indoors, the day named or
the first day left. If Open-Meteo doesn't answer the plan still comes back, with `dry: null`.

Nothing here is stored and nothing but ids, sizes and timings is logged: not the words, not
the plan.
"""

import logging
import re
import time as clock
import unicodedata
from collections.abc import Callable
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from enum import StrEnum
from typing import Any, Protocol

import httpx
from pydantic import BaseModel, ConfigDict

import rsvp
import voice_signup as voice
from organiser import gates, text
from organiser.weather import Day, WeatherUnavailable
from proposals import BARRIOS

log = logging.getLogger(__name__)

WINDOW_DAYS = 7
MIN_LEAD = timedelta(hours=1)
"""A plan is at least this far ahead: nobody sets out in ten minutes."""
EARLIEST, LATEST = time(7, 0), time(21, 0)
"""The hours a plan may be at: the gates' quiet hours run from 21:00 to 09:00 for messages, but
a walk at 07:00 is fine; nothing after 21:00."""
SPAN_HOURS = 2
"""How long the forecast reads from the plan's hour."""
WET_PROBABILITY, WET_MM = 40, 0.5
MAX_ACTIVITY, MAX_PLACE, MAX_TYPED, MAX_SPOKEN = 80, 60, 300, 1_000

KINDS = ["walk", "feria", "library", "call", "noPhone", "other"]
DEFAULT_TIMES = {
    "walk": time(18, 0),
    "feria": time(10, 0),
    "library": time(16, 0),
    "call": time(18, 0),
    "noPhone": time(16, 0),
    "other": time(17, 0),
}
WEEKDAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
TOPICS = ["health", "diet", "money", "people"]
UNCLEAR = "unclear"


def _enum(name: str, values: list[str]) -> type[StrEnum]:
    return StrEnum(name, {value: value for value in values})


DayId = _enum("DayId", [*WEEKDAYS, voice.UNKNOWN])
KindId = _enum("KindId", KINDS)
FlagId = _enum("FlagId", ["none", *TOPICS])


class Draft(BaseModel):
    """What Spark 1.3 fills. Strict: every key required, `unknown` or empty when not said."""

    model_config = ConfigDict(extra="forbid")
    activity: str
    day: DayId
    time: str
    place: str
    kind: KindId
    outdoor: bool
    flag: FlagId


@dataclass(frozen=True)
class Shaped:
    """A draft that passed the filter: `day` is a weekday id and `time` an `HH:MM`, each `None`
    when the member didn't say."""

    activity: str
    day: str | None
    time: str | None
    place: str | None
    kind: str
    outdoor: bool


@dataclass(frozen=True)
class Rejected:
    """A plan the filter dropped, and why: one of `TOPICS` or `UNCLEAR`."""

    reason: str


# --- The filter ---------------------------------------------------------------------------


def _plain(words: str) -> str:
    """Lower case without accents, so one pattern reads "presión" and "presion"."""
    decomposed = unicodedata.normalize("NFD", words.lower())
    return "".join(letter for letter in decomposed if not unicodedata.combining(letter))


_HEALTH = re.compile(
    r"\b(?:salud\w*|enferm\w*|medic\w*|doctor\w*|dolor\w*|terapi\w*|psicolog\w*|psiquiatr\w*|"
    r"deprim\w*|depresion|ansiedad|estres|presion|colesterol|diabet\w*|rehabilit\w*|kinesi\w*|"
    r"fisioterap\w*|ejercicio\w*|bienestar|(?:el|mi|buen|mal|de)\s+animo|pastilla\w*|remedio\w*|tratamiento\w*|"
    r"cirug\w*|hospital\w*|sanatorio\w*|health\w*|illness|pain|therap\w*|exercis\w*|workout)\b"
)
_DIET = re.compile(
    r"\b(?:diet\w*|ayuno\w*|caloria\w*|calories|adelgaz\w*|bajar\s+(?:de\s+)?peso|"
    r"bajar\s+kilos|perder\s+peso|comer\s+(?:sano|menos)|alimentacion|nutri\w*|weight)\b"
)
_MONEY = re.compile(
    r"\b(?:comprar\w*|compras?|gastar\w*|ahorr\w*|deuda\w*|sueldo|cajero|buys?|bought|"
    r"spend(?:s|ing)?|spent|money|pay(?:s|ing|ments?)?|costs?|costly|dollars?)\b"
)
_RELATIVES = (
    r"hij\w+|niet\w+|espos\w+|marido|mujer|novi\w+|pareja|ex|vecin\w+|amig\w+|herman\w+|madre|"
    r"padre|mama|papa|abuel\w+|prim[oa]s?|jef[ea]|compa\w+|suegr\w+|cunad\w+|sobrin\w+|tio|tia|tios"
)
_PEOPLE = re.compile(
    rf"\b(?:mi|mis)\s+(?:{_RELATIVES})\b|"
    r"\bmy\s+(?:son|daughter|wife|husband|friend|neighbou?rs?|mother|father|sister|brother|"
    r"boss|partner|grand\w+)\b"
)
_NAMED = re.compile(
    r"(?i:\bcon|\b(?:llamar|llamo|visitar|ver|invitar|saludar|buscar|acompanar)\s+a|"
    r"\b(?:call|visit|see|meet)(?:\s+with)?)\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]{2,}"
)


def topic(words: str) -> str | None:
    """The first of `TOPICS` the words are about, or `None`. The word lists are Spanish, with
    the English the app's other language needs."""
    plain = _plain(words)
    if _HEALTH.search(plain):
        return "health"
    if _DIET.search(plain):
        return "diet"
    if text.money(words) or _MONEY.search(plain):
        return "money"
    if _PEOPLE.search(plain) or _NAMED.search(words):
        return "people"
    return None


def filter_plan(draft: Draft, words: str) -> Shaped | Rejected:
    """The plan the member's `words` and the model's `draft` agree on, or why there is none."""
    if draft.flag != "none":
        return Rejected(str(draft.flag))
    if found := topic(words):
        return Rejected(found)
    activity = _tidy(draft.activity, MAX_ACTIVITY)
    place = _tidy(draft.place, MAX_PLACE)
    if not activity:
        return Rejected(UNCLEAR)
    if found := topic(f"{activity} {place}"):
        return Rejected(found)
    verdict = gates.check_words(f"{activity}\n{place}")
    if not verdict.allowed:
        return Rejected(UNCLEAR)
    return Shaped(
        activity=activity[0].upper() + activity[1:],
        day=None if draft.day == voice.UNKNOWN else str(draft.day),
        time=_hour(draft.time),
        place=place or None,
        kind=str(draft.kind),
        outdoor=draft.outdoor,
    )


def _tidy(words: str, limit: int) -> str:
    return text.strip_markdown(words)[:limit].strip()


_HOUR = re.compile(r"^(?:[01]\d|2[0-3]):[0-5]\d$")


def _hour(value: str) -> str | None:
    """`HH:MM` when it is one inside the hours a plan may be at, else `None`."""
    if not _HOUR.match(value) or not EARLIEST <= time.fromisoformat(value) <= LATEST:
        return None
    return value


# --- The day ------------------------------------------------------------------------------


class Forecast(Protocol):
    """The forecast source: each day from `first` to `last` (`OpenMeteo.days`)."""

    def days(self, lat: float, lng: float, first: date, last: date) -> dict[date, Day]: ...


@dataclass(frozen=True)
class Slot:
    """When a plan happens: the date, the time, whether the forecast calls it dry (`None`
    when there is no forecast) and whether the day moved from the one the member named."""

    on: date
    at: time
    dry: bool | None
    moved: bool = False


def candidate_days(now: datetime, at: time) -> list[date]:
    """The days in the next week at least `MIN_LEAD` after `now` at hour `at`, in order."""
    here = rsvp.local(now)
    first = here.date()
    return [
        day
        for day in (first + timedelta(days=offset) for offset in range(WINDOW_DAYS + 1))
        if datetime.combine(day, at, tzinfo=rsvp.MONTEVIDEO) >= here + MIN_LEAD
    ][:WINDOW_DAYS]


def forecast_week(weather: Forecast, barrio: object, now: datetime) -> dict[date, Day]:
    """The week's forecast at a barrio's centroid; empty when the barrio is unknown or
    Open-Meteo doesn't answer."""
    centroid = BARRIOS.get(barrio) if isinstance(barrio, str) else None
    if centroid is None:
        return {}
    first = rsvp.local(now).date()
    try:
        return weather.days(
            centroid["lat"], centroid["lng"], first, first + timedelta(days=WINDOW_DAYS)
        )
    except WeatherUnavailable as error:
        log.warning("forecast failed (%s)", error)
        return {}


def rain_at(week: dict[date, Day], on: date, at: time) -> int | None:
    """The rain probability the plan's hours worst-case read, or `None` when the forecast has
    no word on them. A wet hour reads as at least `WET_PROBABILITY`."""
    day = week.get(on)
    if day is None:
        return None
    try:
        reading = day.forecast(on, at.hour, SPAN_HOURS)
    except WeatherUnavailable:
        return None
    if reading.rain_mm >= WET_MM:
        return max(reading.rain_probability, WET_PROBABILITY)
    return reading.rain_probability


def choose_slot(
    days: list[date],
    at: time,
    *,
    named: date | None,
    outdoor: bool,
    week: dict[date, Day],
) -> Slot | None:
    """The day among `days` (never empty for the caller's checks) a plan at `at` happens:
    `None` when `days` is empty."""
    if not days:
        return None
    wanted = named if named in days else None
    if not outdoor:
        return Slot(wanted or days[0], at, None)
    rain = {day: rain_at(week, day, at) for day in days}
    known = [day for day in days if rain[day] is not None]
    if not known:
        return Slot(wanted or days[0], at, None)
    if wanted is not None and rain[wanted] is not None and rain[wanted] < WET_PROBABILITY:
        return Slot(wanted, at, True)
    dry = [day for day in known if rain[day] < WET_PROBABILITY]
    if dry:
        chosen = min(dry, key=lambda day: (abs((day - wanted).days), day)) if wanted else dry[0]
        return Slot(chosen, at, True, moved=wanted is not None and chosen != wanted)
    return Slot(min(known, key=lambda day: (rain[day], day)), at, False)


def named_date(weekday: str | None, days: list[date]) -> date | None:
    """The first of `days` on the weekday the member named."""
    if weekday is None:
        return None
    return next((day for day in days if WEEKDAYS[day.weekday()] == weekday), None)


def schedule(shaped: Shaped, *, now: datetime, week: dict[date, Day]) -> Slot | None:
    """When a shaped plan happens, or `None` when no day is left for its hour."""
    at = time.fromisoformat(shaped.time) if shaped.time else DEFAULT_TIMES[shaped.kind]
    days = candidate_days(now, at)
    return choose_slot(
        days, at, named=named_date(shaped.day, days), outdoor=shaped.outdoor, week=week
    )


# --- Reading the words ----------------------------------------------------------------------

INSTRUCTIONS = """Sos el lector de planes chicos de Ronda: una persona cuenta algo que quiere
hacer esta semana. Te llega lo que dijo. Completá los campos solo con lo que dijo: no inventes.

- activity: qué quiere hacer, en una frase corta en voseo, con las palabras de la persona
  ("Caminar 30 minutos por la rambla"). Sin emoji.
- day: el día que dijo (mon lun, tue mar, wed mié, thu jue, fri vie, sat sáb, sun dom), o
  "unknown" si no dijo ninguno. "Mañana" o "pasado" se cuentan desde hoy, que es {today}.
- time: la hora que dijo como HH:MM de 24 horas ("a las siete de la tarde" es 19:00), o
  "unknown" si no dijo hora.
- place: dónde, como lo dijo y con su preposición ("en la plaza", "desde la parada 23"), o
  vacío si no dijo.
- kind: walk (caminar, pasear), feria (ir a la feria), library (ir a la biblioteca), call
  (llamar a alguien), noPhone (un rato sin el celular) u other.
- outdoor: true si es al aire libre.
- flag: health si habla de salud, médicos o ejercicio como tratamiento; diet si habla de dieta
  o peso; money si habla de plata o de comprar; people si nombra a otra persona o a un
  familiar, vecino o amigo; si no, none. "Alguien" sin nombre no es people.
"""


class BadWords(ValueError):
    """The member gave nothing to read: empty, or a note with no words in it."""


def read_draft(words: str, now: datetime, *, client: Any) -> Draft:
    """The `Draft` Spark 1.3 fills from the member's words. `client` is an `openai.OpenAI` on
    the Meta base URL."""
    here = rsvp.local(now)
    today = f"{WEEKDAYS[here.weekday()]} {here.date().isoformat()}"
    try:
        response = client.chat.completions.parse(
            model=voice.FIELDS_MODEL,
            response_format=Draft,
            reasoning_effort="low",
            messages=[
                {"role": "system", "content": INSTRUCTIONS.format(today=today)},
                {"role": "user", "content": words},
            ],
        )
    except Exception as error:  # the SDK's errors share no useful base with httpx's
        raise voice.ModelUnavailable(type(error).__name__) from error
    draft = response.choices[0].message.parsed
    if draft is None:
        raise voice.ModelUnavailable("no parsed plan")
    return draft


def words_of_note(
    *,
    uid: str,
    path: object,
    blob: Callable[[str], voice.Blob],
    api_key: str,
    http: httpx.Client,
) -> str:
    """What the voice note at `path` says, read by Voice Transcribe. The note is deleted in
    every case once it was found, so it never outlives the call."""
    if voice.note_uid(path) != uid:
        raise PermissionError("not your voice note")
    note = blob(str(path))
    started = clock.perf_counter()
    try:
        audio = note.download_as_bytes()
        seconds = voice.check_wav(audio)
        words = voice.transcribe(audio, api_key=api_key, http=http)
        log.info(
            "small plan %s: %d bytes, %.1f s of audio, transcribe %d ms",
            path,
            len(audio),
            seconds,
            (clock.perf_counter() - started) * 1000,
        )
        return words
    finally:
        try:
            note.delete()
        except Exception as error:  # a missing note; the 1-day lifecycle rule is the backstop
            log.warning("small plan %s: delete failed (%s)", path, type(error).__name__)


def wire(shaped: Shaped, slot: Slot) -> dict[str, Any]:
    """The plan as the app reads it."""
    return {
        "activity": shaped.activity,
        "date": slot.on.isoformat(),
        "time": slot.at.strftime("%H:%M"),
        "place": shaped.place,
        "kind": shaped.kind,
        "outdoor": shaped.outdoor,
        "dry": slot.dry,
        "moved": slot.moved,
    }


def shape_words(
    words: str,
    *,
    now: datetime,
    barrio: object,
    weather: Forecast,
    client: Any,
) -> dict[str, Any]:
    """`{"plan": {...}}` for what the member said, or `{"rejected": reason}`.

    The member's words are checked before any model sees them. Raises `BadWords` for nothing
    to read and `voice.ModelUnavailable` when Spark 1.3 fails.
    """
    words = words.strip()
    if not words:
        raise BadWords("empty")
    if found := topic(words):
        return {"rejected": found}
    shaped = filter_plan(read_draft(words, now, client=client), words)
    if isinstance(shaped, Rejected):
        return {"rejected": shaped.reason}
    slot = schedule(shaped, now=now, week=forecast_week(weather, barrio, now))
    if slot is None:
        return {"rejected": UNCLEAR}
    return {"plan": wire(shaped, slot)}


def shape_request(
    *,
    uid: str,
    data: object,
    user: dict[str, Any] | None,
    now: datetime,
    blob: Callable[[str], voice.Blob],
    api_key: str,
    http: httpx.Client,
    client: Any,
    weather: Forecast,
) -> dict[str, Any]:
    """The `shape_small_plan` callable: `data` is `{text}` (typed), `{transcript}` (what Voice
    Transcribe heard live, `relay/`) or `{path}` (a voice note).

    Refuses callers who haven't accepted the terms. Raises `voice.TermsMissing`, `BadWords`
    and `voice.BadVoiceNote` for what can't be read, `PermissionError` for another person's
    note, and `voice.ModelUnavailable` when a model kept failing.
    """
    if not (user or {}).get("terms"):
        raise voice.TermsMissing(uid)
    data = data if isinstance(data, dict) else {}
    typed, spoken, path = data.get("text"), data.get("transcript"), data.get("path")
    if isinstance(typed, str):
        words = typed[:MAX_TYPED]
    elif isinstance(spoken, str):
        words = " ".join(spoken.split())[:MAX_SPOKEN]
    elif path is not None:
        words = words_of_note(uid=uid, path=path, blob=blob, api_key=api_key, http=http)
    else:
        raise BadWords("no words and no note")
    return shape_words(
        words, now=now, barrio=(user or {}).get("barrio"), weather=weather, client=client
    )
