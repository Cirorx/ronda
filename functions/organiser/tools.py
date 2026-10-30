"""The organiser's tools, for one ronda and one meeting per run.

Each tool takes its arguments as a pydantic model (`extra="forbid"`, every field required, a
`reason` always; "" stands for "none", since `Optional` would put `anyOf` in the schema), is
safe to call again, and is logged: one trace step and one acta line per call, the latter in
es-419 written here. The model learns no member's name: counts only. The ronda is the run's,
so no tool takes a ronda or a barrio.

- `get_forecast(date)`: the meeting hours' worst rain probability, rain and gusts (Open-Meteo).
- `get_sunset(date)`: the sunset at the ronda's place.
- `get_last_bus(date)`: the last bus from the stop a tear-off flyer of the barrio stored
  (`flyers/{id}.lastBus`, computed once from the DNT timetable by scripts/last_bus.py).
- `count_rsvps()`: going, can't and unanswered for the meeting (`rondas/{id}/views/week`).
- `propose_move(place_id, postpone_to)`: the rain options to the host, only when the forecast
  makes rain likely; once per meeting (`rondas/{id}/moves/{week}`).
- `send_member_push(text)`: a routine message to the members, through every gate.
- `log_acta(summary)`: one line of the model's own in the acta, after the word gates.
"""

import json
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, ValidationError

import rsvp
from organiser import gates, moves, outbox, text
from organiser.model import ToolCall
from organiser.trace import Trace
from organiser.weather import SOURCE, Weather, WeatherUnavailable

RAIN_LIKELY = 60
"""A meeting hour at or above this rain probability (%) makes rain likely."""

FORECAST_DAYS = 7
"""How far ahead the forecast is asked for."""

POSTPONE_DAYS = 3
"""A meeting moves at most this many days later."""

DAY_TYPES = ("weekday",) * 5 + ("saturday", "sunday")


class Args(BaseModel):
    """What every tool takes: why the model calls it."""

    model_config = ConfigDict(extra="forbid")
    reason: str = Field(
        min_length=3, max_length=300, description="Por qué llamás a esta herramienta, corto."
    )


class DateArgs(Args):
    date: str = Field(pattern=r"^\d{4}-\d{2}-\d{2}$", description="La fecha, AAAA-MM-DD.")


class ProposeArgs(Args):
    place_id: str = Field(
        max_length=100, description='El id de un lugar techado de la lista, o "" si no hay.'
    )
    postpone_to: str = Field(
        pattern=r"^(\d{4}-\d{2}-\d{2})?$",
        description='Otro día para la reunión, AAAA-MM-DD, hasta 3 días después, o "".',
    )


class PushArgs(Args):
    text: str = Field(min_length=1, max_length=300, description="El mensaje, en voseo.")


class ActaArgs(Args):
    summary: str = Field(
        min_length=1, max_length=200, description="Una línea para el acta, en voseo."
    )


class ToolError(ValueError):
    """A tool call the loop can't run: unknown tool, arguments that aren't JSON or don't fit."""


@dataclass(frozen=True)
class Result:
    """What a tool answers the model, and its one-line summary for the trace and the acta
    (`acta=False` for a repeat that adds nothing new)."""

    data: dict
    summary: str
    status: str = "ok"
    acta: bool = True


MEETING_SPAN = 2
"""How many hours of forecast a meeting with a set hour reads: its length."""


@dataclass(frozen=True)
class Meeting:
    """The meeting a run is about."""

    ronda_id: str
    ronda: dict
    day: date
    hour: str | None
    """When it starts ("16:00"), once the admin set it; until then only its band is known."""
    week: str
    lat: float
    lng: float

    @property
    def band(self) -> str:
        """The slot's time band (`afternoon`)."""
        band = (self.ronda.get("slot") or {}).get("time")
        return band if band in rsvp.BANDS else "afternoon"

    @property
    def at(self) -> str:
        """ "a las 16:00", or the band's words ("a la tarde") while there is no hour: the
        messages never invent one."""
        return f"a las {self.hour}" if self.hour else rsvp.BAND_LABELS[self.band]

    @property
    def when(self) -> str:
        """ "16:00" or "a la tarde", after the weekday: "Jueves 16:00"."""
        return self.hour or rsvp.BAND_LABELS[self.band]

    @property
    def window(self) -> tuple[int, int]:
        """The forecast hours it reads: from its start for `MEETING_SPAN` hours (one more when
        it starts at the half hour), or the whole band while there is no hour."""
        if self.hour:
            start, minutes = int(self.hour[:2]), int(self.hour[3:])
            return start, MEETING_SPAN + (1 if minutes else 0)
        first, end = rsvp.BANDS[self.band]
        return first, end - first

    @property
    def place(self) -> gates.Place | None:
        """The ronda's own place, public by the data model, once a host set one."""
        place = self.ronda.get("place")
        if isinstance(place, dict) and place.get("name"):
            return gates.Place(place["name"])
        return None


@dataclass
class Toolbox:
    """The tools for one run, and what they need."""

    db: Any
    now: datetime
    meeting: Meeting
    weather: Weather
    send: Callable[[list[dict]], list[str]]
    app_url: str
    trace: Trace
    host: outbox.Recipient
    host_fallback: bool
    covered: dict[str, moves.CoveredPlace]
    model_name: Callable[[], str] = lambda: ""
    clock: Callable[[], float] = time.perf_counter
    _notes: set[str] = field(default_factory=set)

    def specs(self) -> list[dict]:
        """The tools as Chat Completions `tools`."""
        return [
            {
                "type": "function",
                "function": {
                    "name": name,
                    "description": description,
                    "parameters": model.model_json_schema(),
                },
            }
            for name, (description, model, _) in TOOLS.items()
        ]

    def parse(self, call: ToolCall) -> Args:
        """The call's arguments, validated; `ToolError` says what was wrong, for the retry."""
        if call.name not in TOOLS:
            raise ToolError(
                f"No existe la herramienta {call.name!r}. Usá una de: {', '.join(TOOLS)}."
            )
        try:
            return TOOLS[call.name][1].model_validate_json(call.arguments or "{}")
        except ValidationError as error:
            problems = "; ".join(
                f"{'.'.join(str(part) for part in e['loc']) or 'argumentos'}: {e['msg']}"
                for e in error.errors()
            )
            raise ToolError(f"Argumentos inválidos para {call.name}: {problems}") from error

    def run(self, name: str, args: Args) -> dict:
        """Runs one validated call, logs it in the trace and the acta, and returns what the
        model reads back."""
        started = self.clock()
        n = self.trace.step(
            "tool",
            tool=name,
            argsSummary=_args_summary(args),
            reason=args.reason,
            resultSummary="",
            status="running",
            latencyMs=0,
            model=self.model_name(),
        )
        result = TOOLS[name][2](self, args)
        self.trace.update(
            n,
            resultSummary=result.summary,
            status=result.status,
            latencyMs=round((self.clock() - started) * 1000),
        )
        if result.acta:
            self.trace.acta(name, result.summary)
        return {"status": result.status, **result.data}

    def day(self, value: str) -> date | None:
        """`value` as a date from today to `FORECAST_DAYS` ahead, or None."""
        try:
            day = date.fromisoformat(value)
        except ValueError:
            return None
        today = rsvp.local(self.now).date()
        return day if today <= day <= today + timedelta(days=FORECAST_DAYS) else None

    def forecast(self, day: date):
        return self.weather.day(self.meeting.lat, self.meeting.lng, day).forecast(
            day, *self.meeting.window
        )


def _args_summary(args: Args) -> str:
    fields = args.model_dump(exclude={"reason"})
    return json.dumps(fields, ensure_ascii=False) if fields else ""


def _day_label(day: date) -> str:
    return f"{moves.weekday(day)} {day.day}/{day.month}"


def _refused(summary: str, **data) -> Result:
    return Result({"error": summary, **data}, summary, "refused")


def get_forecast(box: Toolbox, args: DateArgs) -> Result:
    if (day := box.day(args.date)) is None:
        return _refused(f"No pidió un día con pronóstico: {args.date}.")
    try:
        forecast = box.forecast(day)
    except WeatherUnavailable:
        return _refused(f"No pudo leer el pronóstico del {_day_label(day)}.")
    likely = forecast.rain_probability >= RAIN_LIKELY
    return Result(
        {
            "date": day.isoformat(),
            "hour": forecast.hour,
            "rainProbability": forecast.rain_probability,
            "rainMm": forecast.rain_mm,
            "gustsKmh": forecast.gusts_kmh,
            "rainLikely": likely,
            "source": SOURCE,
        },
        f"Miró el pronóstico del {_day_label(day)} {box.meeting.at}: lluvia "
        f"{forecast.rain_probability}%, ráfagas de {forecast.gusts_kmh} km/h ({SOURCE}).",
    )


def get_sunset(box: Toolbox, args: DateArgs) -> Result:
    if (day := box.day(args.date)) is None:
        return _refused(f"No pidió un día con pronóstico: {args.date}.")
    try:
        sunset = box.weather.day(box.meeting.lat, box.meeting.lng, day).sunset
    except WeatherUnavailable:
        return _refused(f"No pudo leer a qué hora atardece el {_day_label(day)}.")
    return Result(
        {"date": day.isoformat(), "sunset": sunset},
        f"Miró a qué hora atardece el {_day_label(day)}: {sunset}.",
    )


def get_last_bus(box: Toolbox, args: DateArgs) -> Result:
    try:
        day = date.fromisoformat(args.date)
    except ValueError:
        return _refused(f"No es una fecha: {args.date}.")
    barrio = box.meeting.ronda.get("barrio")
    day_type = DAY_TYPES[day.weekday()]
    for flyer in sorted(
        (s.to_dict() for s in box.db.collection("flyers").stream()),
        key=lambda f: f.get("barrio") != barrio,
    ):
        near = flyer.get("barrio") == barrio or barrio in flyer.get("nearBarrios", [])
        bus = (flyer.get("lastBus") or {}).get(day_type)
        if near and isinstance(bus, dict) and bus.get("time"):
            stop = (flyer.get("stop") or {}).get("name", "")
            return Result(
                {
                    "dayType": day_type,
                    "time": bus["time"],
                    "route": bus.get("route", ""),
                    "estimated": bool(bus.get("estimated")),
                    "stop": stop,
                },
                f"Miró el último ómnibus del {_day_label(day)}: {bus['time']}"
                + (f", línea {bus['route']}" if bus.get("route") else "")
                + " (horario publicado).",
            )
    return Result(
        {"dayType": day_type, "time": None},
        "Buscó el último ómnibus: no hay horario guardado para este barrio.",
    )


def count_rsvps(box: Toolbox, args: Args) -> Result:
    snapshot = box.db.document(f"rondas/{box.meeting.ronda_id}/views/week").get()
    view = (snapshot.to_dict() or {}) if snapshot.exists else {}
    if view.get("week") != box.meeting.week:
        view = {}
    going, no = len(view.get("going", [])), int(view.get("noCount", 0))
    unanswered = int(view.get("unansweredCount", 0))
    return Result(
        {"week": box.meeting.week, "going": going, "no": no, "unanswered": unanswered},
        f"Contó las respuestas: van {going}, no pueden {no}, sin contestar {unanswered}.",
    )


def propose_move(box: Toolbox, args: ProposeArgs) -> Result:
    meeting = box.meeting
    move_ref = box.db.document(f"rondas/{meeting.ronda_id}/moves/{meeting.week}")
    if move_ref.get().exists:
        return Result(
            {"proposed": True}, "Ya le había propuesto qué hacer al anfitrión esta semana."
        )
    try:
        forecast = box.forecast(meeting.day)
    except WeatherUnavailable:
        return _refused("No propuso nada: no pudo leer el pronóstico.")
    if forecast.rain_probability < RAIN_LIKELY:
        return _refused(
            f"No propuso nada: el pronóstico da {forecast.rain_probability}% de lluvia, menos "
            f"del {RAIN_LIKELY}%."
        )
    covered = None
    if args.place_id:
        if args.place_id not in box.covered:
            return _refused(
                f"No propuso nada: {args.place_id!r} no es un lugar techado de la lista.",
                places=list(box.covered),
            )
        covered = box.covered[args.place_id]
    postpone_to = None
    if args.postpone_to:
        try:
            postpone_to = date.fromisoformat(args.postpone_to)
        except ValueError:
            return _refused(f"No propuso nada: {args.postpone_to} no es una fecha.")
        if not meeting.day < postpone_to <= meeting.day + timedelta(days=POSTPONE_DAYS):
            return _refused(
                f"No propuso nada: {args.postpone_to} no está entre el día siguiente a la "
                f"reunión y {POSTPONE_DAYS} días después."
            )

    # The gates come first, before anything is written: a held proposal leaves no move behind,
    # so a later run inside the hours proposes cleanly.
    host = box.host
    title, body = moves.host_message(meeting.day, meeting.when, forecast)
    draft = outbox.prepare(
        box.db, host, title=title, text=body, kind=gates.HOST, week=meeting.week, now=box.now
    )
    link = f"{box.app_url.rsplit('/', 1)[0]}/lluvia/{meeting.ronda_id}/{meeting.week}"
    data = {"type": moves.MOVE_TYPE, "rondaId": meeting.ronda_id, "week": meeting.week}
    if not draft.verdict.allowed:
        outbox.deliver(box.db, box.trace, draft, send=box.send, data=data, link=link, now=box.now)
        return Result(
            {"proposed": False, "held": draft.verdict.reason},
            f"Frenó la propuesta a {host.first_name}: {draft.verdict.reason}.",
            "held",
        )
    if rsvp.local(box.now) >= moves.deadline(meeting.day):
        return _refused("No propuso nada: ya pasó la hora para que el anfitrión elija.")
    choices = moves.options(meeting.day, meeting.at, host.first_name, covered, postpone_to)
    recipients = [uid for uid in _members_in(box) if uid != host.uid]
    move_ref.set(
        {
            "week": meeting.week,
            "date": meeting.day.isoformat(),
            "hour": meeting.hour,
            "hostUid": host.uid,
            "hostName": host.first_name,
            "hostFallback": box.host_fallback,
            "title": title,
            "body": body,
            "runId": box.trace.run_id,
            "forecast": {
                "rainProbability": forecast.rain_probability,
                "rainMm": forecast.rain_mm,
                "gustsKmh": forecast.gusts_kmh,
            },
            "options": choices,
            "recipients": len(recipients),
            "deadline": moves.deadline(meeting.day),
            "status": moves.PENDING,
            "createdAt": box.now,
        }
    )
    try:
        outcome = outbox.deliver(
            box.db, box.trace, draft, send=box.send, data=data, link=link, now=box.now
        )
    except Exception:
        move_ref.delete()
        raise
    labels = ", ".join(moves.lower_first(choice["label"]) for choice in choices)
    who = f"{host.first_name}, que abre" if not box.host_fallback else host.first_name
    return Result(
        {"proposed": True, "options": [c["id"] for c in choices], "delivery": outcome},
        f"Le propuso a {who}, qué hacer por la lluvia: {labels}.",
    )


def _members_in(box: Toolbox) -> list[str]:
    """The members the meeting counts: in the ronda and not paused over it."""
    members = {
        s.id: s.to_dict()
        for s in box.db.collection(f"rondas/{box.meeting.ronda_id}/members").stream()
    }
    return sorted(
        uid
        for uid, member in rsvp.counted(members).items()
        if not rsvp._paused_on(member, box.meeting.day)
    )


def send_member_push(box: Toolbox, args: PushArgs) -> Result:
    meeting = box.meeting
    words = text.strip_markdown(args.text)
    week_ref = box.db.document(f"rondas/{meeting.ronda_id}/weeks/{meeting.week}")
    week = week_ref.get()
    routine_sent = week.exists and bool((week.to_dict() or {}).get("rsvpSentAt"))
    title = rsvp.ronda_line(meeting.ronda)
    names = rsvp._first_names(box.db, _members_in(box))
    outcomes: dict[str, int] = {}
    reasons: set[str] = set()
    for uid, name in names.items():
        draft = outbox.prepare(
            box.db,
            outbox.Recipient(uid, name),
            title=title,
            text=words,
            kind=gates.ROUTINE,
            week=meeting.week,
            now=box.now,
            place=meeting.place,
            routine_sent=routine_sent,
        )
        outcome = outbox.deliver(
            box.db,
            box.trace,
            draft,
            send=box.send,
            data={"type": moves.AGENT_TYPE, "rondaId": meeting.ronda_id},
            link=box.app_url,
            now=box.now,
        )
        outcomes[outcome] = outcomes.get(outcome, 0) + 1
        if not draft.verdict.allowed:
            reasons.add(draft.verdict.reason)
    sent, held = outcomes.get("sent", 0), outcomes.get("held", 0)
    if held and not sent:
        return Result(
            {"sent": 0, "held": held, "why": sorted(reasons)},
            f"Frenó un mensaje para los miembros: {'; '.join(sorted(reasons))}.",
            "held",
        )
    return Result(
        {"sent": sent, "held": held, "unreachable": outcomes.get("unreachable", 0)},
        f"Les avisó a {sent}: «{words}».",
    )


def log_acta(box: Toolbox, args: ActaArgs) -> Result:
    words = text.strip_markdown(args.summary)
    verdict = gates.check_words(words)
    if not verdict.allowed:
        return _refused(f"Quiso anotar algo que no pasó los controles: {verdict.reason}.")
    if words in box._notes:
        return Result({"logged": True}, words, acta=False)
    box._notes.add(words)
    return Result({"logged": True}, words)


TOOLS: dict[str, tuple[str, type[Args], Callable[[Toolbox, Any], Result]]] = {
    "get_forecast": (
        "Pronóstico de Open-Meteo para las horas de la reunión: probabilidad de lluvia, "
        "lluvia y ráfagas.",
        DateArgs,
        get_forecast,
    ),
    "get_sunset": ("A qué hora atardece ese día en el lugar de la ronda.", DateArgs, get_sunset),
    "get_last_bus": (
        "El último ómnibus de ese día desde la parada del barrio (horario publicado).",
        DateArgs,
        get_last_bus,
    ),
    "count_rsvps": (
        "Cuántos van, cuántos no pueden y cuántos no contestaron para la reunión.",
        Args,
        count_rsvps,
    ),
    "propose_move": (
        "Le propone al anfitrión qué hacer por la lluvia: un lugar techado de la lista, otro "
        "día, y siempre seguir igual. Solo si la lluvia es probable. Una vez por semana.",
        ProposeArgs,
        propose_move,
    ),
    "send_member_push": (
        "Un mensaje de rutina a los miembros. Pasa por los controles: uno por semana, nunca "
        "de noche.",
        PushArgs,
        send_member_push,
    ),
    "log_acta": ("Una línea para el acta que leen los miembros.", ActaArgs, log_acta),
}
