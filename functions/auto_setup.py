"""Where, when and who for a ronda that forms itself: the organiser agent proposes, code checks
(docs/PRODUCT.md § Joining and forming rondas, "Solver + approval"; auto_form.py).

For each group of an auto proposal, Muse Spark Open on Baseten (Spark 1.3 as fallback, the
organiser's `FallbackModel`) calls `propose_setup` once with:
- a public meeting place from the ones it is offered: the cached OpenStreetMap places
  (free_places.py) nearest the group, never an address or a private place;
- the hour, inside the slot's band;
- who opens (the anfitrión); the next in the rotation's cycle closes (rotation.py).

The model never learns a name: members are `m1`, `m2`… with their age band and how many blocks
each place is from their barrio. Code checks every field before it is accepted: a place id it
offered, open at that hour when its hours are known; an hour inside the band; a host who is one
of the labels; a reason that passes the word gates. A refused call gets the reason back and one
more turn. The accepted reason is stored with the labels replaced by first names.

Fallback (`code_setup`): when there is no model, the run fails, or it ends without an accepted
call, code picks the nearest offered place open at the band's usual hour (`DEFAULT_HOURS`), that
hour, and the rotation's first pair. When even that fails (no cached place near the group) the
setup is None and the proposal waits for the admin.

Every run is a trace, `agent_runs/auto_{proposalId}_{n}` (organiser/trace.py), with job
`auto_setup`: the model's turns, the tool call, and a `note` with what was kept. Its `rondaId`
is filled once the proposal is approved (auto_form.py).

A setup, on `proposals/{id}.groups[n].setup`: placeId, place {name}, hour, anfitrion, cola,
anfitrionName, colaName, reason, by (`agent` | `code`), runId.
"""

import logging
import re
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import date, datetime, time

from pydantic import Field

import free_places
import hosts
import opening_hours
import rsvp
from organiser import gates, text
from organiser import tools as organiser_tools
from organiser.agent import run_agent
from organiser.model import ModelClient, ModelUnavailable
from organiser.tools import Args, Result, Toolbox
from organiser.trace import Trace
from proposals import BARRIOS
from ronda_solver.geo import blocks_between

log = logging.getLogger(__name__)

JOB = "auto_setup"

AGENT = "agent"
CODE = "code"
"""`setup.by`: who chose it."""

DEFAULT_HOURS = {"morning": "10:00", "afternoon": "16:00", "evening": "19:00"}
"""The band's usual hour, when code chooses: inside every band (rsvp.hour_in_band)."""

PLACES_OFFERED = 8
"""How many of the nearest places the model chooses from."""

MAX_STEPS = 4
"""Model turns per setup: the call, a retry after a refusal, the last words."""

FALLBACK_REASON = (
    "Lo eligió el programa por regla fija: el lugar público más cerca del grupo, la hora de "
    "siempre de la franja y el primero de la rotación."
)

SYSTEM = """Sos el organizador de Ronda, un programa que ayuda a grupos de vecinos que se \
juntan todas las semanas. Hacés solo logística: lugares, horarios y quién abre.

Tu tarea ahora: un grupo nuevo se va a juntar por primera vez. Elegí con propose_setup, una \
sola vez:
- place_id: uno de los lugares públicos de la lista, el que mejor quede para todos y para la \
actividad. Nunca una casa ni una dirección.
- hour: la hora de la reunión, HH:MM, dentro de la franja que te digo. Si el lugar tiene \
horario, que esté abierto a esa hora.
- host: quién abre (llega diez minutos antes y saluda), uno de m1, m2…; mejor alguien que \
quede cerca del lugar.
- reason: por qué, en una línea corta para quien arma las rondas, en tercera persona, sin \
Markdown ni emoji. A la persona nombrala como m1, m2… Por ejemplo: "La rambla queda a cinco \
cuadras de todos y va con el mate; abre m2, que vive más cerca."

Después terminá con una frase."""


class SetupArgs(Args):
    reason: str = Field(
        min_length=3,
        max_length=200,
        description="Por qué ese lugar, esa hora y esa persona, en una línea, en voseo.",
    )
    place_id: str = Field(max_length=100, description="El id de un lugar de la lista.")
    hour: str = Field(pattern=r"^\d{2}:\d{2}$", description="La hora, HH:MM, dentro de la franja.")
    host: str = Field(pattern=r"^m\d{1,2}$", description="Quién abre: m1, m2…")


@dataclass(frozen=True)
class Group:
    """What a setup is about: one group of a proposal, as code sees it."""

    pretext: str
    band: str
    day: date
    """The first meeting's date, for opening hours."""
    order: list[str]
    """The rotation's cycle: every member, by when they joined (all at once) and uid."""
    names: dict[str, str]
    places: list[free_places.Place]
    walks: dict[str, dict[str, int]]
    """Blocks from each member's barrio to each offered place: `walks[place_id][uid]`."""

    @property
    def labels(self) -> dict[str, str]:
        """ "m1" for the first in `order`, and so on."""
        return {f"m{n}": uid for n, uid in enumerate(self.order, start=1)}

    def place(self, place_id: str) -> free_places.Place | None:
        return next((p for p in self.places if p.id == place_id), None)

    def open_at(self, place: free_places.Place, hour: str) -> bool:
        return opening_hours.open_at(place.hours, self.day, time.fromisoformat(hour))

    def pair(self, anfitrion: str) -> tuple[str, str]:
        """`(anfitrión, cola)`: the cola is the next in the cycle (rotation.next_pair's rule)."""
        index = self.order.index(anfitrion)
        return anfitrion, self.order[(index + 1) % len(self.order)]

    def setup(self, place: free_places.Place, hour: str, anfitrion: str, **fields) -> dict:
        opens, closes = self.pair(anfitrion)
        return {
            "placeId": place.id,
            "place": {"name": place.name},
            "hour": hour,
            "anfitrion": opens,
            "cola": closes,
            "anfitrionName": self.names[opens],
            "colaName": self.names[closes],
            **fields,
        }


def group_of(db, proposal_group: dict, users: dict[str, dict], now: datetime) -> Group:
    """The setup's view of one `proposals/{id}.groups[n]`: the places nearest the members'
    barrios (their centroid; the seat's barrio for anyone in an unknown one), each member's
    walk to each."""
    day_id, _, band = proposal_group["slot"].partition("-")
    uids = sorted(m["uid"] for m in proposal_group["members"])
    homes = {
        uid: _centroid(users.get(uid, {}).get("barrio"), proposal_group["barrio"]) for uid in uids
    }
    here = (
        sum(lat for lat, _ in homes.values()) / len(homes),
        sum(lng for _, lng in homes.values()) / len(homes),
    )
    places = [p for p in free_places.near(db, here) if len(p.name) <= hosts.NAME_LIMIT][
        :PLACES_OFFERED
    ]
    return Group(
        pretext=proposal_group["pretext"],
        band=band if band in rsvp.BANDS else "afternoon",
        day=rsvp.next_meeting(day_id, rsvp.local(now).date()),
        order=uids,
        names={m["uid"]: m["firstName"] for m in proposal_group["members"]},
        places=places,
        walks={
            place.id: {
                uid: round(blocks_between(home, (place.lat, place.lng)))
                for uid, home in homes.items()
            }
            for place in places
        },
    )


def _centroid(barrio: object, seat_barrio: str) -> tuple[float, float]:
    centroid = BARRIOS.get(barrio) if isinstance(barrio, str) else None
    centroid = centroid or BARRIOS[seat_barrio]
    return centroid["lat"], centroid["lng"]


def code_setup(group: Group, run_id: str) -> dict | None:
    """The fixed rule: the nearest offered place open at the band's usual hour, that hour, and
    the cycle's first pair; None without such a place."""
    hour = DEFAULT_HOURS[group.band]
    place = next((p for p in group.places if group.open_at(p, hour)), None)
    if place is None:
        return None
    return group.setup(place, hour, group.order[0], reason=FALLBACK_REASON, by=CODE, runId=run_id)


@dataclass
class SetupBox:
    """`propose_setup` for one group, with the organiser's tool plumbing (Toolbox's)."""

    trace: Trace
    group: Group
    run_id: str
    model_name: Callable[[], str] = lambda: ""
    clock: Callable[[], float] = organiser_tools.time.perf_counter
    tools: dict = field(default_factory=dict)
    setup: dict | None = None
    """What the model proposed, once code accepted it."""

    specs = Toolbox.specs
    parse = Toolbox.parse
    run = Toolbox.run


def starts(band: str) -> str:
    """ "entre las 14:00 y las 17:00": the starts `band` allows (rsvp.hour_in_band)."""
    first, end = rsvp.BANDS[band]
    return f"entre las {first:02d}:00 y las {end - rsvp.MEETING_HOURS:02d}:00"


_LABEL = re.compile(r"\bm(\d{1,2})\b")


def refusal(group: Group, args: SetupArgs) -> str:
    """Why code refuses the call, in es-419 for the model's retry; "" when every field holds."""
    place = group.place(args.place_id)
    if place is None:
        return f"{args.place_id!r} no es un lugar de la lista. Usá uno de sus ids."
    if not rsvp.hour_in_band(args.hour, group.band):
        return f"{args.hour} queda fuera de la franja: elegí {starts(group.band)}."
    if not group.open_at(place, args.hour):
        return f"{place.name} está cerrado a las {args.hour} ({place.hours})."
    if args.host not in group.labels:
        return f"{args.host} no es del grupo: elegí uno de {', '.join(group.labels)}."
    if not (verdict := gates.check_words(text.strip_markdown(args.reason))).allowed:
        return f"El reason {verdict.reason}."
    return ""


def propose_setup(box: SetupBox, args: SetupArgs) -> Result:
    if box.setup is not None:
        return Result(
            {"error": "Ya propuso."},
            "Ya propuso el lugar, la hora y quién abre.",
            "refused",
            acta=False,
        )
    if why := refusal(box.group, args):
        return Result({"error": why}, f"Rechazado por el código: {why}", "refused", acta=False)
    labels = box.group.labels
    reason = _LABEL.sub(
        lambda found: box.group.names.get(labels.get(found.group(0), ""), found.group(0)),
        text.strip_markdown(args.reason),
    )
    place = box.group.place(args.place_id)
    box.setup = box.group.setup(
        place, args.hour, labels[args.host], reason=reason, by=AGENT, runId=box.run_id
    )
    return Result(
        {"accepted": True},
        f"Propuso {place.name} a las {args.hour}; abre {args.host}. El código lo aceptó.",
        acta=False,
    )


TOOLS = {
    "propose_setup": (
        "Propone el lugar público, la hora y quién abre para la primera reunión del grupo. "
        "Una sola vez.",
        SetupArgs,
        propose_setup,
    ),
}


def task(group: Group) -> str:
    """What the model is told: the activity, the band, the places and each member's walk to
    them, the members as labels with their age band. No name, no barrio."""
    lines = [
        f"Actividad: {rsvp.PRETEXT_LABELS.get(group.pretext, group.pretext)}.",
        f"Primera reunión: {rsvp.DAY_LABELS[rsvp.DAYS[group.day.weekday()]].lower()} "
        f"{group.day.isoformat()}, {rsvp.BAND_LABELS[group.band]}: empieza "
        f"{starts(group.band)}.",
        f"Grupo: {', '.join(group.labels)}.",
        "Lugares (id: nombre, tipo, horario, cuadras desde cada uno):",
    ]
    for place in group.places:
        walks = ", ".join(
            f"{label} {group.walks[place.id][uid]}" for label, uid in group.labels.items()
        )
        lines.append(
            f"- {place.id}: {place.name}, {place.kind}, {place.hours or 'sin horario'}; {walks}."
        )
    return "\n".join(lines)


def set_up(
    db,
    run_id: str,
    group: Group,
    now: datetime,
    get_model: Callable[[], ModelClient],
) -> dict | None:
    """One group's setup: the model's when code accepts it, else code's; None when neither
    holds. The whole run lands in `agent_runs/{run_id}`."""
    trace = Trace(db, run_id, ronda_id="", week=rsvp.iso_week(group.day), now=now)
    setup = None
    if group.places:
        try:
            model = get_model()
        except ModelUnavailable as error:
            trace.start(job=JOB, model="", forced=False)
            trace.step("stop", why=f"no hay modelo ({error})", model="")
            outcome_status = "failed"
        else:
            trace.start(job=JOB, model=model.name, forced=False)
            box = SetupBox(
                trace=trace, group=group, run_id=run_id, model_name=lambda: model.name, tools=TOOLS
            )
            try:
                outcome = run_agent(
                    model=model,
                    toolbox=box,
                    system=SYSTEM,
                    task=task(group),
                    trace=trace,
                    max_steps=MAX_STEPS,
                )
                outcome_status = outcome.status
            except Exception as error:
                log.error("auto_setup %s failed: %s", run_id, type(error).__name__)
                trace.step("stop", why=f"falló ({type(error).__name__})", model="")
                outcome_status = "failed"
            setup = box.setup
    else:
        trace.start(job=JOB, model="", forced=False)
        outcome_status = "done"
    if setup is None:
        setup = code_setup(group, run_id)
        why = (
            "no quedó una propuesta del modelo aceptada" if group.places else "no hay lugares cerca"
        )
        if setup is None:
            trace.step("note", note=f"Sin lugar, hora y anfitrión: {why}. Espera al admin.")
        else:
            trace.step(
                "note",
                note=f"Regla fija ({why}): {setup['place']['name']} a las {setup['hour']}, "
                f"abre {setup['anfitrionName']} y cierra {setup['colaName']}.",
            )
    else:
        trace.step(
            "note",
            note=f"Aceptado: {setup['place']['name']} a las {setup['hour']}, abre "
            f"{setup['anfitrionName']} y cierra {setup['colaName']}. {setup['reason']}",
        )
    trace.finish(outcome_status, setup["reason"] if setup else "")
    return setup


def complete(setup: object) -> bool:
    """Whether a stored setup carries everything approval writes."""
    return (
        isinstance(setup, dict)
        and all(
            isinstance(setup.get(key), str) and setup.get(key)
            for key in ("hour", "anfitrion", "cola")
        )
        and isinstance((setup.get("place") or {}).get("name"), str)
    )
