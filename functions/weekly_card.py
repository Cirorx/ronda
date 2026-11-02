"""The weekly card the organiser agent composes (#62), behind a switch.

The Mi ronda card is a fixed template. With `rondas/{id}.agentCard` on, once per ronda and
week the organiser agent (Muse Spark Open on Baseten, Spark 1.3 as fallback) puts the card's
notices together from Ronda's own catalog of blocks, and the phone draws the stored result with
genui (A2UI messages). It is still one card a week: no feed, no chat, and the phone never
calls a model.

Who decides what:
- The model reads the forecast, the sunset, the last bus and the counts (the rain check's
  tools) and calls `compose_card` once with the blocks it wants, each a kind from the catalog
  with a title and a text in voseo. It never sees a member's name: a block about the host, a
  newcomer or the después carries a placeholder (`{anfitrion}`, `{nuevo}`, `{despues}`) and
  code fills it. The RSVP block is always there; code adds it.
- Code validates every block against the catalog (pydantic: the kinds, lengths, one of each),
  drops a block whose fact doesn't hold this week (no host, nobody new, no después, nobody on
  the bench), strips Markdown, and runs every title and text through the word gates (no emoji,
  voseo, no money, no home or address). A dropped block is a `note` step in the trace. The
  hours gate holds the job itself: nothing is composed from 21:00 to 09:00.
- The phone renders what is stored and nothing else; taps go through the RSVP path, never
  back to the model.

Fallback: any error, timeout, a run that never composes, or a card with no block left, stores
a `template` card with the reason, and the phone shows today's template. With the switch off
nothing runs, and the phone ignores whatever card document is left.

Where things live (docs/ARCHITECTURE.md § Data model):
- `rondas/{id}.agentCard`: the switch, set by the admin (`set_ronda_setup`); off by default.
- `rondas/{id}/views/card`: week, status (`agent` | `template`), reason (why the template),
  messages (the A2UI messages, status `agent`), blocks (the kinds kept), dropped (how many),
  model, runId, latencyMs, tokens ([{model, in, out}], what each model billed), updatedAt.
  Members read it through the `views/{view}` rule.
- `agent_runs/{rondaId}_{week}_card`: the run's trace, as every organiser run.

- `run_weekly_card(db, now, send=...)`: the job (`jobs.JOBS["weekly_card"]`), hourly from the
  dispatcher and by name from the admin's `run_job`: each ronda with the switch on, inside the
  hours, within `DAYS_AHEAD` days of its meeting, once a week (the run is claimed in a
  transaction; a failed one may be claimed again). `force` skips the timing and the claim,
  never the switch or the hours gate.
"""

import logging
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

import rain
import rsvp
from organiser import gates, moves, outbox, text
from organiser import tools as organiser_tools
from organiser.agent import FAILED, run_agent
from organiser.model import ModelClient, ModelUnavailable, Turn, from_environment
from organiser.tools import Args, Meeting, Result, Toolbox
from organiser.trace import Trace
from organiser.weather import OpenMeteo, Weather

log = logging.getLogger(__name__)

JOB = "weekly_card"
VIEW = "card"
"""`rondas/{id}/views/{VIEW}`."""

CATALOG_ID = "uy.ronda.card"
"""The phone's genui catalog: Ronda's own blocks, nothing else."""

A2UI_VERSION = "v0.9"

AGENT = "agent"
TEMPLATE = "template"

DAYS_AHEAD = 3
"""The card is composed from this many days before the meeting, before the RSVP push."""

NEWCOMER_DAYS = 7
"""A member who joined within this many days is new to the ronda."""

RAIN, HOST, NEWCOMER, DESPUES, BENCH, RSVP = "rain", "host", "newcomer", "despues", "bench", "rsvp"
KINDS = (RAIN, HOST, NEWCOMER, DESPUES, BENCH)
COMPONENTS = {
    RAIN: "RainNotice",
    HOST: "HostOfWeek",
    NEWCOMER: "Newcomer",
    DESPUES: "DespuesSpot",
    BENCH: "BenchNudge",
    RSVP: "Rsvp",
}
"""Each kind's component name in the phone's catalog."""

PLACEHOLDERS = {HOST: "{anfitrion}", NEWCOMER: "{nuevo}", DESPUES: "{despues}"}
"""What the model writes where a name or the después goes; code fills it."""

TITLE_LIMIT = 60
TEXT_LIMIT = 240
MAX_BLOCKS = len(KINDS)

SYSTEM = """Sos el organizador de Ronda, un programa que ayuda a grupos de vecinos que se \
juntan todas las semanas. Hacés solo logística: horarios, lugares y lluvia. No decidís nada \
por los vecinos.

Tu tarea ahora: armar la tarjeta de esta semana con los bloques del catálogo que valgan la \
pena. La tarjeta ya dice dónde y cuándo se juntan y pregunta si van: vos agregás solo avisos.
1. Mirá el pronóstico de la reunión con get_forecast. Si hace falta, mirá el atardecer \
(get_sunset), el último ómnibus (get_last_bus) y cuántos van (count_rsvps).
2. Llamá compose_card una sola vez con los bloques, en el orden en que se leen:
   - rain: solo si la lluvia es probable (rainLikely): qué dice el pronóstico y el plan \
alternativo en una línea. Si se juntan igual ese día, podés sumar que un día de lluvia pide \
tortas fritas.
   - host: solo si hay anfitrión esta semana: quién abre, con {anfitrion} en lugar del nombre.
   - newcomer: solo si se suma alguien nuevo: una bienvenida corta, con {nuevo} en lugar del \
nombre.
   - despues: solo si hay después: una línea, con {despues} en lugar de qué y dónde. Nunca \
una dirección.
   - bench: solo si hay alguien en la lista de espera: que avisar "esta no" le da el lugar a \
esa persona.
   Cada bloque lleva un título corto y un texto de una o dos frases.
3. Al final dejá una sola línea en el acta con log_acta, en tercera persona ("Armó…"), y \
terminá con una frase.

Reglas: cada herramienta lleva un reason corto y concreto. No inventes nombres ni lugares: \
usá los marcadores. Sin Markdown y sin emoji. Nada de plata. Escribí en voseo rioplatense."""


class Block(BaseModel):
    """One block of the card, as the model writes it."""

    model_config = ConfigDict(extra="forbid")
    kind: Literal["rain", "host", "newcomer", "despues", "bench"] = Field(
        description="Qué bloque es: rain, host, newcomer, despues o bench."
    )
    title: str = Field(min_length=1, max_length=TITLE_LIMIT, description="Un título corto.")
    text: str = Field(
        min_length=1, max_length=TEXT_LIMIT, description="Una o dos frases, en voseo."
    )


class CardArgs(Args):
    blocks: list[Block] = Field(
        max_length=MAX_BLOCKS, description="Los bloques de la tarjeta, en orden de lectura."
    )


@dataclass(frozen=True)
class Facts:
    """What holds this week, from code, never from the model."""

    host_name: str = ""
    newcomer_name: str = ""
    despues: str = ""
    """ "bizcochos en lo de Mirta" or "bizcochos en la Plaza"; never an address."""
    bench: bool = False

    def holds(self, kind: str) -> bool:
        """Whether a block of `kind` has its fact this week."""
        return {
            RAIN: True,
            HOST: bool(self.host_name),
            NEWCOMER: bool(self.newcomer_name),
            DESPUES: bool(self.despues),
            BENCH: self.bench,
        }[kind]

    def fill(self, words: str) -> str:
        """`words` with the placeholders replaced by this week's facts."""
        return (
            words.replace(PLACEHOLDERS[HOST], self.host_name)
            .replace(PLACEHOLDERS[NEWCOMER], self.newcomer_name)
            .replace(PLACEHOLDERS[DESPUES], self.despues)
        )

    def lines(self) -> str:
        """What the model is told, in its task: yes or no, never a name."""

        def yes_no(value: object) -> str:
            return "sí" if value else "no"

        return "\n".join(
            [
                f"Anfitrión esta semana: {yes_no(self.host_name)}.",
                f"Se suma alguien nuevo: {yes_no(self.newcomer_name)}.",
                f"Hay después: {yes_no(self.despues)}.",
                f"Alguien en la lista de espera: {yes_no(self.bench)}.",
            ]
        )


@dataclass
class CardToolbox(Toolbox):
    """The rain check's reading tools and `compose_card`, which keeps what it kept."""

    facts: Facts = field(default_factory=Facts)
    card: list[dict] | None = None
    """The blocks kept, once the model composed; None until it does."""
    dropped: list[str] = field(default_factory=list)


MISSING = {
    HOST: "no hay anfitrión esta semana",
    NEWCOMER: "no se suma nadie nuevo esta semana",
    DESPUES: "no hay después esta semana",
    BENCH: "no hay nadie en la lista de espera",
}


def compose_card(box: CardToolbox, args: CardArgs) -> Result:
    """Keeps the blocks that fit: one of each kind, only when its fact holds, through the word
    gates with Markdown stripped; the rest is dropped and noted in the trace."""
    if box.card is not None:
        return organiser_tools._refused("Ya armó la tarjeta de esta semana.")
    kept: list[dict] = []
    seen: set[str] = set()
    for block in args.blocks:
        title, body = text.strip_markdown(block.title), text.strip_markdown(block.text)
        why = _why_dropped(box.facts, block.kind, title, body, seen)
        if why:
            box.dropped.append(block.kind)
            box.trace.step("note", note=f"Bloque {block.kind} descartado: {why}.")
            continue
        seen.add(block.kind)
        kept.append(
            {"kind": block.kind, "title": box.facts.fill(title), "text": box.facts.fill(body)}
        )
    box.card = kept
    kinds = ", ".join(b["kind"] for b in kept) or "ninguno"
    summary = f"Armó la tarjeta de la semana con {len(kept)} aviso(s): {kinds}."
    if box.dropped:
        summary += f" Descartó {len(box.dropped)}."
    return Result({"kept": [b["kind"] for b in kept], "dropped": list(box.dropped)}, summary)


def _why_dropped(facts: Facts, kind: str, title: str, body: str, seen: set[str]) -> str:
    if kind in seen:
        return "repetido"
    if not facts.holds(kind):
        return MISSING[kind]
    if not title or not body:
        return "quedó vacío sin el Markdown"
    verdict = gates.check_words(f"{title}\n{body}")
    return "" if verdict.allowed else verdict.reason


CARD_TOOLS = {
    **{
        name: organiser_tools.TOOLS[name]
        for name in ("get_forecast", "get_sunset", "get_last_bus", "count_rsvps")
    },
    "compose_card": (
        "Arma la tarjeta de la semana con los bloques del catálogo, en orden de lectura. "
        "Una sola vez por semana.",
        CardArgs,
        compose_card,
    ),
    "log_acta": organiser_tools.TOOLS["log_acta"],
}


# --- The messages --------------------------------------------------------------------------


def a2ui_messages(week: str, blocks: list[dict]) -> list[dict]:
    """The card as A2UI messages for the phone's catalog: a `RondaCard` root with one component
    per block kept and the RSVP block last."""
    surface = f"card-{week}"
    components = [
        {
            "id": "root",
            "component": "RondaCard",
            "children": [b["kind"] for b in blocks] + [RSVP],
        },
        *[
            {
                "id": b["kind"],
                "component": COMPONENTS[b["kind"]],
                "title": b["title"],
                "text": b["text"],
            }
            for b in blocks
        ],
        {"id": RSVP, "component": COMPONENTS[RSVP]},
    ]
    return [
        {
            "version": A2UI_VERSION,
            "createSurface": {"surfaceId": surface, "catalogId": CATALOG_ID},
        },
        {
            "version": A2UI_VERSION,
            "updateComponents": {"surfaceId": surface, "components": components},
        },
    ]


class Metered:
    """`model`, keeping the tokens each model behind it billed, for the card's cost."""

    def __init__(self, model: ModelClient) -> None:
        self._model = model
        self.tokens: dict[str, list[int]] = {}

    @property
    def name(self) -> str:
        return self._model.name

    def complete(self, messages: list[dict], tools: list[dict]) -> Turn:
        turn = self._model.complete(messages, tools)
        billed = self.tokens.setdefault(turn.model or self._model.name, [0, 0])
        billed[0] += turn.tokens_in
        billed[1] += turn.tokens_out
        return turn

    def summary(self) -> list[dict]:
        return [{"model": m, "in": t[0], "out": t[1]} for m, t in self.tokens.items()]


# --- The job -------------------------------------------------------------------------------


def run_weekly_card(
    db,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
    force: bool = False,
    model: ModelClient | None = None,
    weather: Weather | None = None,
) -> dict:
    """Composes the card of every ronda with the switch on whose meeting is within `DAYS_AHEAD`
    days, inside the hours, once a week. Returns counts."""
    import httpx

    counts = {"rondas": 0, "off": 0, "held": 0, "already": 0, AGENT: 0, TEMPLATE: 0}
    here = rsvp.local(now)
    models: list[ModelClient] = [model] if model else []

    def get_model() -> ModelClient:
        if not models:
            models.append(from_environment())
        return models[0]

    with httpx.Client() as http:
        forecast = weather or OpenMeteo(http)
        for snapshot in db.collection("rondas").stream():
            ronda = snapshot.to_dict()
            if ronda.get("status") not in rsvp.OPEN_STATUSES:
                continue
            counts["rondas"] += 1
            if ronda.get("agentCard") is not True:
                counts["off"] += 1
                continue
            if not rsvp.inside_gate(now):
                counts["held"] += 1
                continue
            ronda_id = snapshot.id
            day = rsvp.next_meeting(ronda["slot"]["day"], here.date())
            week = rsvp.iso_week(day)
            if not (force or (day - here.date()).days <= DAYS_AHEAD):
                continue
            run_id = f"{ronda_id}_{week}_card"
            if force:
                run_id += f"_{here:%Y%m%dT%H%M}"
            elif not rsvp._in_transaction(db, rain._claim(db.document(f"agent_runs/{run_id}"))):
                counts["already"] += 1
                continue
            lat, lng = rain._location(ronda)
            meeting = Meeting(
                ronda_id=ronda_id,
                ronda=ronda,
                day=day,
                hour=rsvp.meeting_hour(ronda),
                week=week,
                lat=lat,
                lng=lng,
            )
            trace = Trace(db, run_id, ronda_id=ronda_id, week=week, now=now)
            try:
                status = compose_ronda(
                    db, meeting, trace, now, get_model, forecast, send, app_url, force
                )
            except Exception as error:
                log.error("weekly_card %s failed: %s", ronda_id, type(error).__name__)
                trace.step("stop", why=f"falló ({type(error).__name__})", model="")
                trace.finish(FAILED)
                status = _store(db, meeting, trace, TEMPLATE, reason="falló")
            counts[status] += 1
    log.info("weekly_card: %s", counts)
    return counts


def compose_ronda(
    db,
    meeting: Meeting,
    trace: Trace,
    now: datetime,
    get_model: Callable[[], ModelClient],
    weather: Weather,
    send,
    app_url: str,
    force: bool,
) -> str:
    """One ronda's card, from the start of its run to the stored result; returns `AGENT` when
    the model's card is stored, `TEMPLATE` when the phone will show the template."""
    try:
        model = Metered(get_model())
    except ModelUnavailable as error:
        trace.start(job=JOB, model="", forced=force)
        trace.step("stop", why=f"no hay modelo ({error})", model="")
        trace.finish(FAILED)
        return _store(db, meeting, trace, TEMPLATE, reason=f"no hay modelo ({error})")
    trace.start(job=JOB, model=model.name, forced=force)
    host, fallback = rain._host(db, meeting.ronda_id, meeting.ronda)
    host_name = host.first_name if host is not None and not fallback else ""
    facts = _facts(db, meeting, now, host_name=host_name)
    box = CardToolbox(
        db=db,
        now=now,
        meeting=meeting,
        weather=weather,
        send=send,
        app_url=app_url,
        trace=trace,
        host=host or outbox.Recipient("", "", outbox.HOST),
        host_fallback=fallback,
        covered={},
        model_name=lambda: model.name,
        tools=CARD_TOOLS,
        facts=facts,
    )
    outcome = run_agent(
        model=model, toolbox=box, system=SYSTEM, task=_task(meeting, facts, now), trace=trace
    )
    trace.finish(outcome.status, outcome.note)
    if box.card is None:
        reason = "el modelo no respondió" if outcome.status == FAILED else "no armó la tarjeta"
        return _store(
            db, meeting, trace, TEMPLATE, reason=reason, dropped=box.dropped, tokens=model
        )
    if not box.card:
        return _store(
            db,
            meeting,
            trace,
            TEMPLATE,
            reason="no quedó ningún aviso",
            dropped=box.dropped,
            tokens=model,
        )
    return _store(db, meeting, trace, AGENT, blocks=box.card, dropped=box.dropped, tokens=model)


def _task(meeting: Meeting, facts: Facts, now: datetime) -> str:
    """What the model is told about this ronda: no names, no addresses."""
    here = rsvp.local(now)
    pretext = rsvp.PRETEXT_LABELS.get(meeting.ronda.get("pretext"), "")
    place = f", en {meeting.place.name}" if meeting.place else ""
    return (
        f"Ronda: {pretext}.\n"
        f"Reunión: {moves.weekday(meeting.day)} {meeting.day.isoformat()} {meeting.at}"
        f"{place}.\n"
        f"Ahora: {moves.weekday(here.date())} {here.date().isoformat()} {here:%H:%M}.\n"
        f"{facts.lines()}"
    )


def _facts(db, meeting: Meeting, now: datetime, *, host_name: str) -> Facts:
    """This week's facts: who opens, who is new, the después (never its address), the bench."""
    members = rsvp.counted(rsvp._members(db, meeting.ronda_id))
    since = now - timedelta(days=NEWCOMER_DAYS)
    new = [
        uid
        for uid, m in members.items()
        if m.get("state", "active") == "active"
        and isinstance(m.get("joinedAt"), datetime)
        and m["joinedAt"] >= since
    ]
    newcomer = ""
    if new and len(members) > len(new):
        first = min(new, key=lambda u: (members[u]["joinedAt"], u))
        newcomer = rsvp._first_names(db, [first])[first]
    despues = _read(db, f"rondas/{meeting.ronda_id}/despues/{meeting.week}")
    words = ""
    if despues.get("status") == "set" and despues.get("what"):
        if despues.get("kind") == "place" and despues.get("where"):
            words = f"{despues['what']} en {despues['where']}"
        elif despues.get("kind") == "home" and despues.get("homeName"):
            words = f"{despues['what']} en lo de {despues['homeName']}"
    bench = bool(_read(db, f"rondas/{meeting.ronda_id}/bench/{meeting.week}").get("offers"))
    return Facts(host_name=host_name, newcomer_name=newcomer, despues=words, bench=bench)


def _read(db, path: str) -> dict:
    snapshot = db.document(path).get()
    return (snapshot.to_dict() or {}) if snapshot.exists else {}


def _store(
    db,
    meeting: Meeting,
    trace: Trace,
    status: str,
    *,
    reason: str = "",
    blocks: list[dict] | None = None,
    dropped: list[str] | None = None,
    tokens: Metered | None = None,
) -> str:
    """Writes `views/card` for the phone and says in the trace what it will show."""
    run = _read(db, f"agent_runs/{trace.run_id}")
    started = run.get("startedAt")
    at = trace.at()
    card = {
        "week": meeting.week,
        "status": status,
        "reason": reason,
        "blocks": [b["kind"] for b in blocks or []],
        "dropped": len(dropped or []),
        "model": run.get("model", ""),
        "runId": trace.run_id,
        "latencyMs": round((at - started).total_seconds() * 1000)
        if isinstance(started, datetime)
        else 0,
        "tokens": tokens.summary() if tokens else [],
        "updatedAt": at,
    }
    if status == AGENT:
        card["messages"] = a2ui_messages(meeting.week, blocks or [])
        note = f"Tarjeta armada por el programa: {len(blocks or [])} aviso(s) y ¿Venís?."
    else:
        note = f"Muestra la tarjeta fija: {reason}."
    db.document(f"rondas/{meeting.ronda_id}/views/{VIEW}").set(card)
    trace.step("note", note=note)
    return status
