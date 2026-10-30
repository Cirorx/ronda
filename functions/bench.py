"""The bench: a seat freed by an "esta no", offered to a neighbour who is waiting (docs/PRODUCT.md
§ The weekly loop, "Bench"; #48, and #50's `offer_bench_seat`).

"Se liberó un lugar para hoy" / "Martes 19:30 · truco · Club Lagomar. Estabas en la lista de
espera. ¿Lo tomás? Tenés hasta las 17:00." [Lo tomo] [Esta vez no]. No fines, ever: saying no or
letting the deadline pass leaves nothing against anyone, and they stay on every bench.

Who decides what. Every step of the run's trace says it (`by`: code, model or person):
- Code owns every hard rule: who is on the bench and in what order (`bench_order`), the needs
  filter (the seat id must be among the person's eligible ids, which the phone worked out from
  needs that never leave it), the gates (quiet hours among them), one offer per freed seat at a
  time, what happens on expiry and on "Esta vez no" (the next person), and, on the real
  project, that the invented `demo-` sign-ups are never on a bench (demo_users.counts).
- The model decides (`_Step.decide`: Muse Spark Open through organiser.agent, with the forecast,
  the sunset, the last bus and the counts as tools): whether an offer is worth sending, which of
  the deadlines code allows it gets, and when the host gets a summary of the bench. When it
  doesn't decide (it failed, timed out, ran out of turns or never called the tool), code sends
  the offer with the default deadline (`default_deadline`) and the trace says so; when it never
  chose a time for the host's summary, code sends it once the bench settles.

The guest: who takes a seat goes to that one meeting and is no member. They land on
`weeks/{w}.guests` (rsvp.guests), which the members' "who's coming" (`views/week`) and the
host's roll ("¿Quién vino hoy?", attendance.people) read; nothing else counts them.

Where things live (docs/ARCHITECTURE.md § Data model):
- `rondas/{id}/bench/{isoWeek}`: the week's bench, server only: offers [{offerId, uid,
  firstName, status}] in the order they went out (each status as the run last saw it), skipped
  (freed seats the model chose not to offer), summary {at, by, sentAt}, notes (what code said
  once), lockedUntil, updatedAt. Only a run holding the lease writes it.
- `users/{uid}/offers/{offerId}` (`{rondaId}_{isoWeek}_{n}`): the offer, read by that person
  only: rondaId, week, date, pretext, slot {day, time}, hour, placeName, placeLandmark,
  deadline, status (pending | taken | declined | expired | withdrawn), createdAt, then
  answeredAt or closedAt. Its status lives here alone, changed in transactions, so the person's
  answer and a run never overwrite each other.
- `agent_runs/{rondaId}_{isoWeek}_bench`: one trace per meeting, its steps added as the bench
  moves. The acta gets a line per tool call and per offer, never a name.

- `run_bench(db, now, send=...)`: the job (`jobs.JOBS["bench"]`), hourly from the dispatcher,
  by name from `run_job`, and for one ronda from main.py's triggers right after an answer to the
  RSVP or to an offer. Deadlines fall on the hour, so the hourly run moves on when one passes.
- `answer(db, uid, offer_id, take, now)`: the `answer_bench_offer` callable's body.
"""

import logging
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, date, datetime, time, timedelta

from pydantic import Field

import demo_users
import rain
import rsvp
from organiser import gates, moves, outbox
from organiser import tools as organiser_tools
from organiser.agent import CAPPED, DONE, FAILED, STOPPED, run_agent
from organiser.model import ModelClient, ModelUnavailable, from_environment
from organiser.tools import Args, Meeting, Result, Toolbox
from organiser.trace import Trace
from organiser.weather import OpenMeteo, Weather

log = logging.getLogger(__name__)

JOB = "bench"
OFFER_TYPE = "benchOffer"
"""`data.type` of the offer push, which the phone draws with [Lo tomo] [Esta vez no]."""

PENDING, TAKEN, DECLINED, EXPIRED, WITHDRAWN = (
    "pending",
    "taken",
    "declined",
    "expired",
    "withdrawn",
)
OFFER, SKIP = "offer", "skip"

MIN_NOTICE = timedelta(hours=1)
"""An offer leaves the person at least this long to answer."""
BEFORE_MEETING = timedelta(hours=1)
"""A deadline falls at least this long before the meeting, so a "no" leaves time for the next
person."""
FIRST_DEADLINE, LAST_DEADLINE = 9, 20
"""Deadlines fall on the hour from 09:00 to 20:00, so the hourly run that moves to the next
person sends inside the gate."""
DEFAULT_NOTICE = timedelta(hours=3)
"""Without the model's decision, the deadline is the first allowed one at least this far ahead,
or the last one when the meeting is nearer."""
LEASE = timedelta(minutes=5)
"""How long a run holds a ronda's bench before another may take it (a crashed run lets go)."""
MAX_STEPS = 8
"""Model turns per offer: the forecast, the sunset, the last bus and the count, the decision,
the host's summary, the last words, and one retry."""
MODEL_TIMEOUT = 20
"""Seconds per model request: an offer can't wait long, and code has a default."""

WHY_DEFAULT = {
    DONE: "El modelo terminó sin decidir",
    CAPPED: "El modelo llegó al tope de pasos sin decidir",
    STOPPED: "La llamada del modelo vino mal dos veces",
    FAILED: "El modelo no respondió a tiempo",
}

COUNTS = ("rondas", "offered", "skipped", "expired", "withdrawn", "summaries", "busy", "failed")


class BenchError(Exception):
    """An answer the callable refuses; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


# --- Time ---------------------------------------------------------------------------------


def meeting_start(ronda: dict, day: date) -> datetime:
    """When the meeting on `day` starts in Montevideo: its hour, or its band's first hour while
    it has none."""
    if hour := rsvp.meeting_hour(ronda):
        start = time.fromisoformat(hour)
    else:
        band = (ronda.get("slot") or {}).get("time")
        start = time(rsvp.BANDS.get(band, rsvp.BANDS["afternoon"])[0])
    return datetime.combine(day, start, tzinfo=rsvp.MONTEVIDEO)


def deadline_window(now: datetime, start: datetime) -> list[datetime]:
    """Every deadline code allows for an offer made at `now` for a meeting at `start`: on the
    hour, from `MIN_NOTICE` after now to `BEFORE_MEETING` before the meeting, between
    `FIRST_DEADLINE` and `LAST_DEADLINE`. Empty when it is too late to offer."""
    earliest = rsvp.local(now) + MIN_NOTICE
    at = earliest.replace(minute=0, second=0, microsecond=0)
    if at < earliest:
        at += timedelta(hours=1)
    window = []
    while at <= start - BEFORE_MEETING:
        if FIRST_DEADLINE <= at.hour <= LAST_DEADLINE:
            window.append(at)
        at += timedelta(hours=1)
    return window


def default_deadline(window: list[datetime], now: datetime) -> datetime:
    """The deadline code gives when the model didn't decide."""
    return next((at for at in window if at >= now + DEFAULT_NOTICE), window[-1])


def spoken_day(day: date, today: date) -> str:
    """ "hoy", "mañana" or "el jueves 5/11"."""
    if day == today:
        return "hoy"
    if day == today + timedelta(days=1):
        return "mañana"
    return f"el {moves.weekday(day)} {day.day}/{day.month}"


def spoken_deadline(at: datetime, now: datetime) -> str:
    """ "las 17:00", "mañana a las 12:00" or "el miércoles 4/11 a las 12:00"."""
    at = rsvp.local(at)
    clock = f"las {at:%H:%M}"
    day = spoken_day(at.date(), rsvp.local(now).date())
    return clock if day == "hoy" else f"{day} a {clock}"


def _iso(at: datetime) -> str:
    return f"{rsvp.local(at):%Y-%m-%dT%H:%M}"


# --- Who is on the bench --------------------------------------------------------------------


@dataclass(frozen=True)
class Candidate:
    """One person on a ronda's bench."""

    uid: str
    first_name: str
    brings: tuple[str, ...]
    waiting_since: datetime | None
    """When they saved their profile: who waited longest is offered first."""
    blocks: float


def freed_seats(members: dict[str, dict], answers: dict[str, str], day: date) -> int:
    """The seats "esta no" freed for the meeting on `day`: every member who said no, or is
    paused over it ("Pausar 2 semanas") and didn't answer, as `views/week` counts "no puede"."""
    return sum(
        1
        for uid, member in rsvp.counted(members).items()
        if answers.get(uid) == rsvp.NO or (uid not in answers and rsvp._paused_on(member, day))
    )


def _seated(db) -> set[str]:
    """Everyone sitting in a ronda that still meets."""
    seated = set()
    for snapshot in db.collection("rondas").stream():
        if (snapshot.to_dict() or {}).get("status") not in rsvp.OPEN_STATUSES:
            continue
        for member in db.collection(f"rondas/{snapshot.id}/members").stream():
            if (member.to_dict() or {}).get("state") in ("active", "paused"):
                seated.add(member.id)
    return seated


def _eligible(db, uid: str) -> list[str]:
    snapshot = db.document(f"users/{uid}/private/eligible").get()
    return list((snapshot.to_dict() or {}).get("seatIds", [])) if snapshot.exists else []


def _busy(db, uid: str, day: date) -> bool:
    """Whether `uid` already holds an offer, or took a seat elsewhere for the same day."""
    for snapshot in db.collection(f"users/{uid}/offers").stream():
        offer = snapshot.to_dict() or {}
        if offer.get("status") == PENDING:
            return True
        if offer.get("status") == TAKEN and offer.get("date") == day.isoformat():
            return True
    return False


def seat_id(ronda: dict) -> str:
    """The ronda's seat id, `{barrio}_{pretext}_{day}-{band}`: what the phone's needs filter
    lets through."""
    slot = ronda.get("slot") or {}
    fallback = f"{ronda.get('barrio')}_{ronda.get('pretext')}_{slot.get('day')}-{slot.get('time')}"
    return ronda.get("seatId") or fallback


def bench_order(db, ronda: dict, day: date, skip: set[str]) -> list[Candidate]:
    """The ronda's bench for the meeting on `day`, in order: sign-ups with a profile who count
    here, sit in no ronda, picked this pretext and slot, live within the solver's walking
    distance, for whom the seat passes their needs filter, and who hold no other offer nor a
    seat elsewhere that day; `skip` (already offered this seat this week) left out. Who waited
    longest comes first, then the nearest."""
    # Both import the solver package, and with it OR-Tools: only a bench with a seat pays.
    from proposals import BARRIOS
    from ronda_solver.geo import blocks_between
    from ronda_solver.rules import MAX_WALK_BLOCKS

    here = BARRIOS.get(ronda.get("barrio"))
    if here is None:
        return []
    slot = ronda.get("slot") or {}
    slot_id, seat = f"{slot.get('day')}-{slot.get('time')}", seat_id(ronda)
    seated = _seated(db)
    found = []
    for snapshot in db.collection("users").stream():
        uid, user = snapshot.id, snapshot.to_dict() or {}
        there = BARRIOS.get(user.get("barrio"))
        if (
            uid in skip
            or uid in seated
            or not demo_users.counts(uid)
            or "firstName" not in user
            or there is None
            or ronda.get("pretext") not in user.get("pretexts", [])
            or slot_id not in user.get("slots", [])
        ):
            continue
        blocks = blocks_between((here["lat"], here["lng"]), (there["lat"], there["lng"]))
        if blocks > MAX_WALK_BLOCKS or seat not in _eligible(db, uid) or _busy(db, uid, day):
            continue
        since = user.get("createdAt")
        found.append(
            Candidate(
                uid=uid,
                first_name=user["firstName"],
                brings=tuple(user.get("brings", [])),
                waiting_since=since if isinstance(since, datetime) else None,
                blocks=blocks,
            )
        )
    latest = datetime.max.replace(tzinfo=UTC)
    found.sort(key=lambda c: (c.waiting_since or latest, c.blocks, c.uid))
    return found


# --- The words ------------------------------------------------------------------------------


def offer_message(ronda: dict, day: date, deadline: datetime, now: datetime) -> tuple[str, str]:
    """The offer, in code: "Se liberó un lugar para hoy" / "Martes 19:30 · truco · Club
    Lagomar. Estabas en la lista de espera. ¿Lo tomás? Tenés hasta las 17:00." What the ronda
    doesn't know yet ("Lugar a confirmar.") goes after its line."""
    title = f"Se liberó un lugar para {spoken_day(day, rsvp.local(now).date())}"
    line = rsvp.ronda_line(ronda)
    unknown = rsvp.to_confirm(ronda)
    body = f"{line}. {unknown + ' ' if unknown else ''}Estabas en la lista de espera. ¿Lo tomás? "
    return title, f"{body}Tenés hasta {spoken_deadline(deadline, now)}."


def _names(names: list[str]) -> str:
    return names[0] if len(names) == 1 else f"{', '.join(names[:-1])} y {names[-1]}"


def summary_message(
    day: date, today: date, freed: int, guests: list[str], pending: int, open_left: int
) -> tuple[str, str]:
    """What the host reads about the bench, in code: how many seats "esta no" freed, who came
    from the waiting list (first names), and what is still being offered or still free. Never
    who said no."""
    when = spoken_day(day, today)
    seats = "un lugar" if freed == 1 else f"{freed} lugares"
    sentences = [f"Para {when} se {'liberó' if freed == 1 else 'liberaron'} {seats}."]
    if guests:
        verb = "viene" if len(guests) == 1 else "vienen"
        sentences.append(f"{_names(guests)} {verb} de la lista de espera.")
    if pending:
        sentences.append("Se lo estamos ofreciendo a alguien más de la lista.")
    if open_left:
        left = "Queda un lugar libre" if open_left == 1 else f"Quedan {open_left} lugares libres"
        sentences.append(f"{left}.")
    return f"Lugares libres del {moves.weekday(day)}", " ".join(sentences)


# --- The model's tools ------------------------------------------------------------------------

SYSTEM = """Sos el organizador de Ronda, un programa que ayuda a grupos de vecinos que se \
juntan todas las semanas. Hacés solo logística.

Tu tarea ahora: alguien de la ronda dijo «esta no» y quedó un lugar libre para la próxima \
reunión. Ronda ya eligió, con reglas fijas, a qué persona de la lista de espera le toca. Vos \
decidís:
1. Si vale la pena ofrecerle el lugar ahora (offer_bench_seat) o no (skip_offer). Mirá cuántas \
horas faltan, si va a llover (get_forecast), a qué hora atardece (get_sunset), el último \
ómnibus (get_last_bus) y cuántos van (count_rsvps). No lo ofrezcas si nadie llegaría a \
organizarse o a volver.
2. Si lo ofrecés, hasta cuándo tiene para contestar: una de las horas permitidas. Con la \
reunión cerca, un plazo corto, así si dice que no Ronda llega a ofrecérselo a otra persona.
3. Cuándo avisarle a quien abre la ronda cómo va el banco (tell_host): ahora, a una hora que \
elijas, o más adelante si todavía no hace falta.

Reglas: cada herramienta lleva un reason corto y concreto. Decidí una sola vez: \
offer_bench_seat o skip_offer, no las dos. No escribas mensajes: Ronda los escribe. Sin \
Markdown y sin emoji. Escribí en voseo rioplatense y terminá con una frase corta."""


class OfferArgs(Args):
    deadline: str = Field(
        pattern=r"^\d{4}-\d{2}-\d{2}T\d{2}:00$",
        description="Hasta cuándo tiene para contestar: una de las horas permitidas, "
        "AAAA-MM-DDTHH:00.",
    )


class TellHostArgs(Args):
    at: str = Field(
        pattern=r"^(\d{4}-\d{2}-\d{2}T\d{2}:00)?$",
        description='Cuándo avisarle: "" para ahora, o una hora AAAA-MM-DDTHH:00 entre las '
        "09:00 y las 20:00, antes de la reunión.",
    )


@dataclass(frozen=True)
class Decision:
    """What happens to one freed seat: `OFFER` with a deadline, or `SKIP`; and who decided."""

    action: str
    deadline: datetime | None
    by: str


@dataclass
class BenchToolbox(Toolbox):
    """The tools for one offer's decision: the rain check's reading tools and the bench's own."""

    window: tuple[datetime, ...] = ()
    start: datetime | None = None
    has_host: bool = False
    host_settled: bool = False
    """Whether the host's summary was already sent or set for a time this week."""
    decision: Decision | None = None
    summary_at: datetime | None = None

    def allowed(self, value: str) -> datetime | None:
        """`value` (`AAAA-MM-DDTHH:00`) in Montevideo, or None when it isn't a time."""
        try:
            return datetime.fromisoformat(value).replace(tzinfo=rsvp.MONTEVIDEO)
        except ValueError:
            return None


def _window_words(box: BenchToolbox) -> str:
    return (
        f"una hora en punto de {_iso(box.window[0])} a {_iso(box.window[-1])}, entre las "
        f"{FIRST_DEADLINE:02d}:00 y las {LAST_DEADLINE}:00"
    )


def offer_bench_seat(box: BenchToolbox, args: OfferArgs) -> Result:
    if box.decision is not None:
        return organiser_tools._refused("Ya decidió qué hacer con este lugar.")
    at = box.allowed(args.deadline)
    if at not in box.window:
        return organiser_tools._refused(
            f"{args.deadline} no es un plazo permitido: elegí {_window_words(box)}."
        )
    box.decision = Decision(OFFER, at, "model")
    day = moves.weekday(box.meeting.day)
    return Result(
        {"decided": OFFER, "deadline": args.deadline},
        f"Decidió ofrecer el lugar libre del {day} a la persona que sigue en la lista de "
        f"espera, con plazo hasta {spoken_deadline(at, box.now)}.",
    )


def skip_offer(box: BenchToolbox, args: Args) -> Result:
    if box.decision is not None:
        return organiser_tools._refused("Ya decidió qué hacer con este lugar.")
    box.decision = Decision(SKIP, None, "model")
    return Result(
        {"decided": SKIP},
        f"Decidió no ofrecer el lugar libre del {moves.weekday(box.meeting.day)} esta semana.",
    )


def tell_host(box: BenchToolbox, args: TellHostArgs) -> Result:
    if not box.has_host:
        return organiser_tools._refused("La ronda no tiene quien abra ni quien cierre.")
    if box.host_settled or box.summary_at is not None:
        return organiser_tools._refused("Ya está decidido cuándo se le avisa esta semana.")
    at = box.now
    if args.at:
        latest = (box.start or box.now) - BEFORE_MEETING
        at = box.allowed(args.at)
        if at is None or not (
            box.now < at <= latest and FIRST_DEADLINE <= at.hour <= LAST_DEADLINE
        ):
            return organiser_tools._refused(
                f'{args.at} no sirve: "" para ahora, o una hora en punto hasta {_iso(latest)}, '
                f"entre las {FIRST_DEADLINE:02d}:00 y las {LAST_DEADLINE}:00."
            )
    box.summary_at = at
    when = spoken_deadline(at, box.now) if args.at else "ahora"
    return Result(
        {"scheduled": args.at or "now"},
        f"Decidió avisarle a quien abre cómo va el banco: {when}.",
    )


BENCH_TOOLS = {
    **{
        name: organiser_tools.TOOLS[name]
        for name in ("get_forecast", "get_sunset", "get_last_bus", "count_rsvps")
    },
    "offer_bench_seat": (
        "Ofrece el lugar libre a la persona que sigue en la lista de espera (la elige Ronda), "
        "con un plazo para contestar. Ronda escribe y manda el mensaje.",
        OfferArgs,
        offer_bench_seat,
    ),
    "skip_offer": (
        "No ofrece este lugar libre esta semana, porque no vale la pena.",
        Args,
        skip_offer,
    ),
    "tell_host": (
        "Le avisa a quien abre la ronda cómo va el banco, ahora o a una hora. Ronda escribe el "
        "mensaje. Una vez por semana.",
        TellHostArgs,
        tell_host,
    ),
}


# --- One ronda's bench ------------------------------------------------------------------------


@dataclass
class _Context:
    send: Callable[[list[dict]], list[str]]
    app_url: str
    force: bool
    get_model: Callable[[], ModelClient]
    weather: Weather


def _lease(run_ref, now: datetime) -> Callable:
    def claim(transaction) -> bool:
        snapshot = run_ref.get(transaction=transaction)
        held = (snapshot.to_dict() or {}).get("lockedUntil") if snapshot.exists else None
        if held is not None and held > now:
            return False
        transaction.set(run_ref, {"lockedUntil": now + LEASE}, merge=True)
        return True

    return claim


def _place(ronda: dict) -> gates.Place | None:
    """The ronda's own place, public by the data model, once one is set."""
    name = rsvp.place_name(ronda)
    return gates.Place(name) if name else None


@dataclass
class _Step:
    """One run over one ronda's bench for its upcoming meeting, holding the lease."""

    db: object
    ronda_id: str
    ronda: dict
    day: date
    now: datetime
    context: _Context
    counts: dict = field(default_factory=dict)
    trace: Trace | None = None

    def __post_init__(self) -> None:
        self.week = rsvp.iso_week(self.day)
        self.start = meeting_start(self.ronda, self.day)
        self.today = rsvp.local(self.now).date()
        self.run_ref = self.db.document(f"rondas/{self.ronda_id}/bench/{self.week}")
        snapshot = self.run_ref.get()
        state = (snapshot.to_dict() or {}) if snapshot.exists else {}
        self.offers: list[dict] = [dict(offer) for offer in state.get("offers", [])]
        self.skipped = int(state.get("skipped", 0))
        self.summary: dict = dict(state.get("summary") or {})
        self.notes: list[str] = list(state.get("notes", []))
        self.members: dict[str, dict] = {}

    # --- the record ---

    def _trace(self) -> Trace:
        if self.trace is None:
            run_id = f"{self.ronda_id}_{self.week}_bench"
            self.trace = Trace(
                self.db, run_id, ronda_id=self.ronda_id, week=self.week, now=self.now
            )
            self.trace.start(job=JOB, model="", forced=self.context.force)
        return self.trace

    def note(self, text: str, once: str = "") -> None:
        """A code step in the trace; with `once`, only the first time this week."""
        if once:
            if once in self.notes:
                return
            self.notes.append(once)
        self._trace().step("note", note=text)

    def count(self, key: str) -> None:
        self.counts[key] = self.counts.get(key, 0) + 1

    def save(self) -> None:
        self.run_ref.set(
            {
                "week": self.week,
                "date": self.day.isoformat(),
                "offers": self.offers,
                "skipped": self.skipped,
                "summary": self.summary,
                "notes": self.notes,
                "updatedAt": self.now,
            },
            merge=True,
        )

    # --- the run ---

    def run(self) -> dict:
        week = self.db.document(f"rondas/{self.ronda_id}/weeks/{self.week}").get()
        self.members = rsvp._members(self.db, self.ronda_id)
        guests = rsvp.guests(week)
        freed = freed_seats(self.members, rsvp._rsvp(week), self.day)
        self.catch_up()
        open_seats = max(freed - len(guests) - self.skipped, 0)
        pending = [offer for offer in self.offers if offer["status"] == PENDING]
        while len(pending) > open_seats:
            self.close(pending.pop(), WITHDRAWN)
        exhausted = False
        if len(pending) < open_seats and rsvp.inside_gate(self.now):
            exhausted = self.offer_seats(pending, open_seats, freed, len(guests))
            open_seats = max(freed - len(guests) - self.skipped, 0)
        if rsvp.inside_gate(self.now):
            settled = not pending and (open_seats == 0 or exhausted)
            self.tell_host(guests, freed, len(pending), open_seats - len(pending), settled)
        self.save()
        if self.trace is not None:
            self.trace.finish(DONE)
        return self.counts

    def catch_up(self) -> None:
        """What happened since the last run: the people's answers (their steps), and offers
        whose deadline passed, which code closes."""
        for offer in self.offers:
            if offer["status"] != PENDING:
                continue
            snapshot = self.db.document(f"users/{offer['uid']}/offers/{offer['offerId']}").get()
            current = (snapshot.to_dict() or {}) if snapshot.exists else {}
            status, deadline = current.get("status", WITHDRAWN), current.get("deadline")
            if status == TAKEN:
                self._trace().step("answer", resultSummary=f"{offer['firstName']} tomó el lugar.")
            elif status == DECLINED:
                self._trace().step(
                    "answer",
                    resultSummary=f"{offer['firstName']} contestó «Esta vez no». Nada cambia "
                    "para esa persona: sigue en la lista de espera.",
                )
            elif status == PENDING and deadline is not None and deadline <= self.now:
                self.close(offer, EXPIRED)
                continue
            offer["status"] = status

    def close(self, offer: dict, status: str) -> None:
        """Ends a pending offer as `status` (expired or withdrawn), unless the person answered
        first: then the next run reads their answer."""
        ref = self.db.document(f"users/{offer['uid']}/offers/{offer['offerId']}")

        def write(transaction) -> bool:
            current = ref.get(transaction=transaction).to_dict() or {}
            if current.get("status") != PENDING:
                return False
            transaction.update(ref, {"status": status, "closedAt": self.now})
            return True

        if not rsvp._in_transaction(self.db, write):
            return
        offer["status"] = status
        self.count(status)
        name = offer["firstName"]
        if status == EXPIRED:
            self.note(
                f"Venció el plazo de {name} sin respuesta: el lugar pasa a la persona que "
                "sigue. Nada cambia para quien no contestó."
            )
        else:
            self.note(
                f"Se retiró la oferta a {name}: alguien de la ronda volvió a decir «voy» y ya "
                "no queda lugar libre."
            )

    def offer_seats(self, pending: list[dict], open_seats: int, freed: int, taken: int) -> bool:
        """Offers seats until each open one has a pending offer; returns whether the bench ran
        out of people or of time."""
        while len(pending) < open_seats:
            window = deadline_window(self.now, self.start)
            if not window:
                self.note(
                    "La reunión está demasiado cerca: ya no da el tiempo para ofrecer el lugar.",
                    once="late",
                )
                return True
            queue = bench_order(self.db, self.ronda, self.day, {o["uid"] for o in self.offers})
            if not queue:
                self.note("No queda nadie en la lista de espera para este lugar.", once="empty")
                return True
            person = queue[0]
            since = (
                f", que espera desde el {rsvp.local(person.waiting_since):%d/%m}"
                if person.waiting_since
                else ""
            )
            people = "persona" if len(queue) == 1 else "personas"
            self.note(
                f"Lugar libre para el {moves.weekday(self.day)}. En la lista de espera hay "
                f"{len(queue)} {people} para este lugar: mismo día y actividad, a menos de diez "
                "cuadras, y el lugar pasa el filtro de lo que le complica ir a cada una. Le toca "
                f"a {person.first_name}{since}."
            )
            decision = self.decide(len(queue), window, freed, taken)
            if decision.action == SKIP:
                self.skipped += 1
                open_seats -= 1
                self.count("skipped")
                self.note(
                    f"El lugar queda sin ofrecer esta semana: a {person.first_name} no le llega "
                    "nada."
                )
                continue
            offer = self.send_offer(person, decision.deadline)
            if offer is None:
                return False
            pending.append(offer)
        return False

    def decide(self, queue: int, window: list[datetime], freed: int, taken: int) -> Decision:
        """The model's decision for one seat, or code's default when it gives none."""
        trace = self._trace()
        try:
            model = self.context.get_model()
        except ModelUnavailable as error:
            return self.default(window, f"No hay modelo ({error})")
        trace.start(job=JOB, model=model.name, forced=self.context.force)
        lat, lng = rain._location(self.ronda)
        box = BenchToolbox(
            db=self.db,
            now=self.now,
            meeting=Meeting(
                self.ronda_id,
                self.ronda,
                self.day,
                rsvp.meeting_hour(self.ronda),
                self.week,
                lat,
                lng,
            ),
            weather=self.context.weather,
            send=self.context.send,
            app_url=self.context.app_url,
            trace=trace,
            host=outbox.Recipient("", "", outbox.HOST),
            host_fallback=False,
            covered={},
            model_name=lambda: model.name,
            tools=BENCH_TOOLS,
            window=tuple(window),
            start=self.start,
            has_host=self.host() is not None,
            host_settled=bool(self.summary),
        )
        outcome = run_agent(
            model=model,
            toolbox=box,
            system=SYSTEM,
            task=self.task(queue, window, freed, taken),
            trace=trace,
            max_steps=MAX_STEPS,
        )
        if box.summary_at is not None:
            self.summary = {"at": box.summary_at, "by": "model"}
        if box.decision is None:
            return self.default(window, WHY_DEFAULT[outcome.status])
        return box.decision

    def default(self, window: list[datetime], why: str) -> Decision:
        deadline = default_deadline(window, self.now)
        self.note(
            f"{why}: Ronda hace lo de siempre y ofrece el lugar con plazo hasta "
            f"{spoken_deadline(deadline, self.now)}."
        )
        return Decision(OFFER, deadline, "code")

    def task(self, queue: int, window: list[datetime], freed: int, taken: int) -> str:
        """What the model is told: counts and times; no name, no address."""
        here = rsvp.local(self.now)
        pretext = rsvp.PRETEXT_LABELS.get(self.ronda.get("pretext"), "")
        place = f", en {name}" if (name := rsvp.place_name(self.ronda)) else ""
        hour = rsvp.meeting_hour(self.ronda)
        at = f"a las {hour}" if hour else rsvp.BAND_LABELS.get(self.ronda["slot"].get("time"), "")
        hours = (self.start - self.now).total_seconds() / 3600
        statuses = [offer["status"] for offer in self.offers]
        host = "ya está decidido" if self.summary else "todavía no se decidió"
        return (
            f"Ronda: {pretext}{place}.\n"
            f"Reunión: {moves.weekday(self.day)} {self.day.isoformat()} {at} "
            f"(faltan {hours:.0f} horas).\n"
            f"Ahora: {moves.weekday(here.date())} {here.date().isoformat()} {here:%H:%M}.\n"
            f"Lugares liberados por «esta no»: {freed}. Tomados por la lista de espera: {taken}. "
            f"Ofertas esta semana: {len(statuses)} (sin contestar {statuses.count(PENDING)}, "
            f"dijeron que no {statuses.count(DECLINED)}, vencidas {statuses.count(EXPIRED)}). "
            f"Lugares que decidiste no ofrecer: {self.skipped}.\n"
            f"Personas en la lista de espera que pueden tomar este lugar: {queue}.\n"
            f"Plazos permitidos: horas en punto de {_iso(window[0])} a {_iso(window[-1])}, entre "
            f"las {FIRST_DEADLINE:02d}:00 y las {LAST_DEADLINE}:00. Si no decidís, Ronda usa "
            f"{_iso(default_deadline(window, self.now))}.\n"
            f"Aviso a quien abre: {host}."
        )

    def send_offer(self, person: Candidate, deadline: datetime) -> dict | None:
        """Writes the offer and sends it through the gates; `None` when a gate held it (the
        person stays first in line for the next run)."""
        trace = self._trace()
        offer_id = f"{self.ronda_id}_{self.week}_{len(self.offers) + 1:02d}"
        title, text = offer_message(self.ronda, self.day, deadline, self.now)
        draft = outbox.prepare(
            self.db,
            outbox.Recipient(person.uid, person.first_name),
            title=title,
            text=text,
            kind=gates.OFFER,
            week=self.week,
            now=self.now,
            place=_place(self.ronda),
        )
        deliver = {
            "send": self.context.send,
            "data": {"type": OFFER_TYPE, "offerId": offer_id, "rondaId": self.ronda_id},
            "link": self.context.app_url,
            "now": self.now,
        }
        if not draft.verdict.allowed:
            outbox.deliver(self.db, trace, draft, **deliver)
            return None
        slot = self.ronda.get("slot") or {}
        place = self.ronda.get("place") if isinstance(self.ronda.get("place"), dict) else {}
        offer_ref = self.db.document(f"users/{person.uid}/offers/{offer_id}")
        offer_ref.set(
            {
                "rondaId": self.ronda_id,
                "week": self.week,
                "date": self.day.isoformat(),
                "pretext": self.ronda.get("pretext", ""),
                "slot": {"day": slot.get("day", ""), "time": slot.get("time", "")},
                "hour": rsvp.meeting_hour(self.ronda),
                "placeName": rsvp.place_name(self.ronda),
                "placeLandmark": place.get("landmark") or None,
                "deadline": deadline,
                "status": PENDING,
                "createdAt": self.now,
            }
        )
        offer = {
            "offerId": offer_id,
            "uid": person.uid,
            "firstName": person.first_name,
            "status": PENDING,
        }
        self.offers.append(offer)
        self.save()
        try:
            outbox.deliver(self.db, trace, draft, **deliver)
        except Exception:
            offer_ref.delete()
            self.offers.pop()
            self.save()
            raise
        trace.acta(
            "offer_bench_seat",
            f"Ofreció el lugar libre del {moves.weekday(self.day)} a alguien de la lista de "
            f"espera, con plazo hasta {spoken_deadline(deadline, self.now)}.",
        )
        self.count("offered")
        return offer

    # --- the host's summary ---

    def host(self) -> outbox.Recipient | None:
        """Who opens the ronda, else who closes it, while active; nobody stands in."""
        hosts = self.ronda.get("hosts") or {}
        active = {
            uid
            for uid, member in rsvp.counted(self.members).items()
            if member.get("state", "active") == "active"
        }
        uid = next((h for h in (hosts.get("anfitrion"), hosts.get("cola")) if h in active), None)
        if uid is None:
            return None
        return outbox.Recipient(uid, rsvp._first_names(self.db, [uid])[uid], outbox.HOST)

    def tell_host(
        self, guests: dict, freed: int, pending: int, open_left: int, settled: bool
    ) -> None:
        """Sends the host's summary once a week: when the time the model chose comes, or, if it
        never chose one, once the bench settles."""
        if self.summary.get("done") or not (self.offers or self.skipped) or not freed:
            return
        at = self.summary.get("at")
        if at is None:
            if not settled:
                return
            self.summary = {"at": self.now, "by": "code"}
            self.note(
                "El modelo no eligió cuándo avisarle a quien abre: Ronda le avisa ahora, que el "
                "banco terminó."
            )
        elif at > self.now:
            return
        self.summary["done"] = True
        host = self.host()
        if host is None:
            self.note("La ronda no tiene quien abra ni quien cierre: el resumen no va a nadie.")
            return
        names = sorted(guest.get("firstName", "") for guest in guests.values())
        title, text = summary_message(
            self.day, self.today, freed, names, pending, max(open_left, 0)
        )
        draft = outbox.prepare(
            self.db, host, title=title, text=text, kind=gates.HOST, week=self.week, now=self.now
        )
        outbox.deliver(
            self.db,
            self._trace(),
            draft,
            send=self.context.send,
            data={"type": moves.AGENT_TYPE, "rondaId": self.ronda_id},
            link=self.context.app_url,
            now=self.now,
        )
        self.summary["sentAt"] = self.now
        self._trace().acta(
            "tell_host",
            f"Le contó a {host.first_name} cómo va el banco del {moves.weekday(self.day)}.",
        )
        self.count("summaries")


def step(db, ronda_id: str, ronda: dict, now: datetime, context: _Context) -> dict:
    """One run over ronda `ronda_id`'s bench for its upcoming meeting; returns counts. Nothing
    is read past the week's answers while no seat is free and the bench never ran; a run that
    finds another holding the lease leaves it (`busy`)."""
    day = rsvp.next_meeting(ronda["slot"]["day"], rsvp.local(now).date())
    if now >= meeting_start(ronda, day):
        return {}
    week = rsvp.iso_week(day)
    run_ref = db.document(f"rondas/{ronda_id}/bench/{week}")
    answers = rsvp._rsvp(db.document(f"rondas/{ronda_id}/weeks/{week}").get())
    if not freed_seats(rsvp._members(db, ronda_id), answers, day) and not run_ref.get().exists:
        return {}
    if not rsvp._in_transaction(db, _lease(run_ref, now)):
        return {"busy": 1}
    bench = _Step(db, ronda_id, ronda, day, now, context)
    try:
        return bench.run()
    except Exception as error:
        trace = bench._trace()
        trace.step("stop", why=f"falló ({type(error).__name__})", model="")
        trace.finish(FAILED)
        raise
    finally:
        run_ref.set({"lockedUntil": None}, merge=True)


def run_bench(
    db,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
    force: bool = False,
    model: ModelClient | None = None,
    weather: Weather | None = None,
    ronda_id: str | None = None,
) -> dict:
    """The bench job: one run over every open ronda's bench, or only `ronda_id`'s (the
    triggers). `force` (the admin's `run_job`) only marks the trace: the bench has no timing to
    skip, and never a gate. The model is built when a seat first needs a decision."""
    import httpx

    counts = dict.fromkeys(COUNTS, 0)
    models: list[ModelClient] = [model] if model else []

    def get_model() -> ModelClient:
        if not models:
            models.append(from_environment(timeout=MODEL_TIMEOUT))
        return models[0]

    if ronda_id is None:
        snapshots = list(db.collection("rondas").stream())
    else:
        snapshots = [db.document(f"rondas/{ronda_id}").get()]
    with httpx.Client() as http:
        context = _Context(send, app_url, force, get_model, weather or OpenMeteo(http))
        for snapshot in snapshots:
            ronda = snapshot.to_dict() if snapshot.exists else None
            if not ronda or ronda.get("status") not in rsvp.OPEN_STATUSES:
                continue
            counts["rondas"] += 1
            try:
                ran = step(db, snapshot.id, ronda, now, context)
            except Exception as error:
                log.error("bench %s failed: %s", snapshot.id, type(error).__name__)
                counts["failed"] += 1
                continue
            for key, value in ran.items():
                counts[key] = counts.get(key, 0) + value
    log.info("bench: %s", counts)
    return counts


# --- The person's answer ----------------------------------------------------------------------


def answer(db, uid: str, offer_id: object, take: object, now: datetime) -> dict:
    """[Lo tomo] (`take`) or [Esta vez no] on `uid`'s own offer, while it is pending and before
    its deadline. Taking puts them on the week's guests and in "who's coming" in one transaction
    with the offer; a second identical answer answers the same and changes nothing. Writes no
    trace: the next bench run reads the answer and records it (main.py's trigger runs it at
    once), so only a run holding the lease writes the bench's records."""
    if not isinstance(offer_id, str) or not offer_id or "/" in offer_id:
        raise BenchError("invalid-argument", "offerId is required")
    if not isinstance(take, bool):
        raise BenchError("invalid-argument", "take is true or false")
    ref = db.document(f"users/{uid}/offers/{offer_id}")
    snapshot = ref.get()
    if not snapshot.exists:
        raise BenchError("not-found", "no such offer")
    offer = snapshot.to_dict()
    wanted = TAKEN if take else DECLINED
    result = {
        "status": wanted,
        "rondaId": offer["rondaId"],
        "week": offer["week"],
        "date": offer["date"],
        "hour": offer.get("hour"),
    }
    if offer.get("status") == wanted:
        return result
    if offer.get("status") != PENDING or now >= offer["deadline"]:
        raise BenchError("failed-precondition", "the offer is over")
    ronda_id, meeting = offer["rondaId"], date.fromisoformat(offer["date"])
    week_ref = db.document(f"rondas/{ronda_id}/weeks/{offer['week']}")
    members = rsvp._members(db, ronda_id)
    names = rsvp._first_names(db, rsvp.counted(members))
    user = db.document(f"users/{uid}").get().to_dict() or {}
    guest = {
        "firstName": user.get("firstName", ""),
        "brings": list(user.get("brings", [])),
        "offerId": offer_id,
        "at": now,
    }

    def write(transaction) -> bool:
        current = ref.get(transaction=transaction).to_dict() or {}
        week = week_ref.get(transaction=transaction)
        if current.get("status") != PENDING:
            return current.get("status") == wanted
        transaction.update(ref, {"status": wanted, "answeredAt": now})
        if take:
            guests = {**rsvp.guests(week), uid: guest}
            transaction.set(
                week_ref, {"date": meeting.isoformat(), "guests": {uid: guest}}, merge=True
            )
            transaction.set(
                db.document(f"rondas/{ronda_id}/views/{rsvp.VIEW}"),
                rsvp.week_view(meeting, members, names, rsvp._rsvp(week), now, guests),
            )
        return True

    if not rsvp._in_transaction(db, write):
        raise BenchError("failed-precondition", "the offer is over")
    return result
