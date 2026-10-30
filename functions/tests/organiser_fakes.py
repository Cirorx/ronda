"""Stand-ins for the organiser's outside world: the model, the forecast, and a rainy week.

`ScriptedModel` answers each request with the next scripted `Turn` (or raises the scripted
error), the way `organiser.model.ChatModel` turns Baseten's stream into one; `streamed` builds
the stream itself, chunk by chunk, in the shapes `scripts/smoke/s4_baseten_tools.py` reads.
`FakeWeather` answers every day with the same hours. Nothing here reaches a network.

The ronda meets on Thursday 2026-11-05 at 16:00 (its `slot.hour`, ISO week 45); the rain check
runs the evening before, Wednesday 2026-11-04 at 18:00 in Montevideo (UTC-3). Every person and
place is invented.
"""

import json
from datetime import UTC, date, datetime, timedelta
from types import SimpleNamespace

import rsvp
from organiser.model import ToolCall, Turn
from organiser.weather import Day, WeatherUnavailable

RONDA = "ronda-rain"
WEEK = "2026-W45"
THURSDAY = date(2026, 11, 5)
JOINED = datetime(2026, 10, 20, 15, 0, tzinfo=UTC)


def at(day: int, hour: int, minute: int = 0, month: int = 11) -> datetime:
    """`day`/`month` 2026 at `hour`:`minute` in Montevideo, as UTC."""
    local = datetime(2026, month, day, hour, minute, tzinfo=rsvp.MONTEVIDEO)
    return local.astimezone(UTC)


WED_18 = at(4, 18)
WED_22 = at(4, 22)
WED_2030 = at(4, 20, 30)
WED_21 = at(4, 21)

MEMBERS = {
    "demo-101": ("Mirta", ["termo"]),
    "demo-102": ("Jorge", ["pan"]),
    "demo-103": ("Ana", ["yerba"]),
    "demo-104": ("Facu", ["tengo-ganas"]),
}
HOST = "demo-101"


def documents(*, hosts: dict | None = None, **ronda_fields) -> dict[str, dict]:
    """A Thursday ronda with four members and their phones, the RSVP already sent this week,
    who's coming, one covered public place nearby, and a tear-off flyer's last bus."""
    ronda = {
        "seatId": "el-pinar-sur_mate_thu-afternoon",
        "pretext": "mate",
        "barrio": "el-pinar-sur",
        "slot": {"day": "thu", "time": "afternoon", "hour": "16:00"},
        "size": 4,
        "status": "active",
        "place": {"name": "frente al quiosco", "landmark": "", "lat": -34.80, "lng": -55.885},
        "createdAt": JOINED,
        **ronda_fields,
    }
    if hosts is not None:
        ronda["hosts"] = hosts
    docs = {f"rondas/{RONDA}": ronda}
    for offset, (uid, (name, brings)) in enumerate(MEMBERS.items()):
        docs[f"rondas/{RONDA}/members/{uid}"] = {
            "brings": brings,
            "state": "active",
            "joinedAt": JOINED + timedelta(minutes=offset),
        }
        docs[f"users/{uid}"] = {"firstName": name, "ageBand": "60-69"}
        docs[f"users/{uid}/tokens/tok-{uid}"] = {"platform": "android"}
    docs["users/demo-102/tokens/tok-web"] = {"platform": "web"}
    docs[f"rondas/{RONDA}/weeks/{WEEK}"] = {
        "date": THURSDAY.isoformat(),
        "rsvp": {"demo-101": "yes", "demo-102": "yes", "demo-103": "no"},
        "rsvpSentAt": at(3, 19),
    }
    docs[f"rondas/{RONDA}/views/week"] = {
        "week": WEEK,
        "date": THURSDAY.isoformat(),
        "going": [
            {"uid": "demo-101", "firstName": "Mirta", "brings": ["termo"]},
            {"uid": "demo-102", "firstName": "Jorge", "brings": ["pan"]},
        ],
        "noCount": 1,
        "unansweredCount": 1,
        "updatedAt": at(3, 20),
    }
    docs["places/salon-pinar"] = {
        "name": "el Salón Comunal de El Pinar",
        "barrios": ["el-pinar-sur", "el-pinar-norte"],
        "covered": True,
        "kind": "public",
    }
    docs["places/plaza-pinar"] = {
        "name": "la Plaza de El Pinar",
        "barrios": ["el-pinar-sur"],
        "covered": False,
        "kind": "public",
    }
    docs["flyers/abcd1234"] = {
        "kind": "tearOff",
        "barrio": "el-pinar-norte",
        "nearBarrios": ["el-pinar-norte", "el-pinar-sur"],
        "stop": {"id": "s1", "name": "Av. Giannattasio y Calle 1"},
        "lastBus": {
            "weekday": {"time": "21:10", "estimated": False, "route": "711"},
            "saturday": None,
            "sunday": None,
        },
    }
    return docs


RAINY = Day(
    hours={16: (80, 2.4, 50), 17: (70, 1.1, 45), 18: (40, 0.2, 30), 19: (75, 1.5, 35)},
    sunset="19:52",
)
DRY = Day(hours={16: (10, 0.0, 15), 17: (5, 0.0, 12)}, sunset="19:52")


class FakeWeather:
    """Every day reads as `day`; `fail=True` makes every read fail."""

    def __init__(self, day: Day = RAINY, fail: bool = False) -> None:
        self._day = day
        self._fail = fail
        self.calls: list[tuple[float, float, date]] = []

    def day(self, lat: float, lng: float, on: date) -> Day:
        self.calls.append((lat, lng, on))
        if self._fail:
            raise WeatherUnavailable("down")
        return self._day


def call(name: str, call_id: str = "", **arguments) -> ToolCall:
    return ToolCall(call_id or f"call_{name}", name, json.dumps(arguments, ensure_ascii=False))


def turn(*calls: ToolCall, content: str = "", model: str = "scripted") -> Turn:
    return Turn(content=content, tool_calls=calls, model=model)


class ScriptedModel:
    """A `ModelClient` that plays back `script`: each item is a `Turn` to answer, or an
    exception to raise. It keeps every request it got."""

    def __init__(self, script: list, name: str = "scripted") -> None:
        self._script = list(script)
        self._name = name
        self.requests: list[tuple[list[dict], list[dict]]] = []

    @property
    def name(self) -> str:
        return self._name

    def complete(self, messages: list[dict], tools: list[dict]) -> Turn:
        self.requests.append(([dict(m) for m in messages], tools))
        item = self._script.pop(0)
        if isinstance(item, Exception):
            raise item
        return item


REASON = "para decidir si hace falta mover la reunión"


def rain_script(*, place_id: str = "salon-pinar", postpone_to: str = "2026-11-06") -> list:
    """What Spark Open does for a rainy Thursday: the forecast, then the sunset, the last bus
    and the count in one turn, the proposal, an acta line, and last words in Markdown."""
    day = THURSDAY.isoformat()
    return [
        turn(call("get_forecast", date=day, reason="ver si llueve a la hora de la ronda")),
        turn(
            call("get_sunset", date=day, reason="saber si hay luz para volver"),
            call("get_last_bus", date=day, reason="saber cómo vuelven"),
            call("count_rsvps", reason="saber cuántos van"),
        ),
        turn(
            call(
                "propose_move",
                place_id=place_id,
                postpone_to=postpone_to,
                reason="llueve 80% a las 16 y hay un salón techado cerca",
            )
        ),
        turn(
            call(
                "log_acta",
                summary="Por la lluvia, propuso un salón techado a quien abre.",
                reason=REASON,
            )
        ),
        turn(content="**Listo**: le propuse opciones al anfitrión."),
    ]


def chunk(content: str | None = None, calls: list | None = None) -> SimpleNamespace:
    """One streamed chunk, shaped like openai's `ChatCompletionChunk`."""
    delta = SimpleNamespace(content=content, tool_calls=calls)
    return SimpleNamespace(choices=[SimpleNamespace(delta=delta)])


def fragment(index: int, call_id=None, name=None, arguments=None) -> SimpleNamespace:
    """One tool-call fragment inside a chunk's delta."""
    function = SimpleNamespace(name=name, arguments=arguments)
    return SimpleNamespace(index=index, id=call_id, function=function)


def streamed(answer: Turn) -> list[SimpleNamespace]:
    """`answer` as Baseten streams it: the words in two pieces, each call's id and name first and
    its arguments in two fragments, then the usage chunk with no choices."""
    chunks = []
    if answer.content:
        half = len(answer.content) // 2
        chunks += [chunk(answer.content[:half]), chunk(answer.content[half:])]
    for index, tool_call in enumerate(answer.tool_calls):
        half = len(tool_call.arguments) // 2
        chunks.append(chunk(calls=[fragment(index, tool_call.id, tool_call.name, "")]))
        chunks.append(chunk(calls=[fragment(index, arguments=tool_call.arguments[:half])]))
        chunks.append(chunk(calls=[fragment(index, arguments=tool_call.arguments[half:])]))
    chunks.append(SimpleNamespace(choices=[]))
    return chunks


class FakeOpenAI:
    """Stands in for `openai.OpenAI`: `chat.completions.create` streams the next answer of
    `answers` (a `Turn`, raw chunks, or an exception to raise) and keeps every request."""

    def __init__(self, answers: list) -> None:
        self._answers = list(answers)
        self.requests: list[dict] = []
        self.chat = SimpleNamespace(completions=SimpleNamespace(create=self._create))

    def _create(self, **request):
        self.requests.append(request)
        answer = self._answers.pop(0)
        if isinstance(answer, Exception):
            raise answer
        return iter(streamed(answer) if isinstance(answer, Turn) else answer)
