"""The day-of reminder: within the hour before a meeting, the members who said "voy" get one
line from the organiser, with the next city buses when there are any (#65).

"Hoy nos vemos a las 16:00 en la Plaza Gomensoro. Próximos ómnibus en 26 de Marzo y Jose
Ellauri, según la Intendencia: el 191 en 6 minutos, el 192 en 15."

On by default: every ronda gets it unless `rondas/{id}.dayOfReminder` is `false` (absent or
`true` is on). The switch has no screen yet: to turn it off, the admin sets the field to `false`
on the ronda's document.

Who decides what:
- The model (the organiser loop, Muse Spark Open with Spark 1.3 as fallback) calls
  `get_next_buses` (the stop nearest the ronda's place, live from the Intendencia de Montevideo,
  mvd_buses.py) and then `send_reminder`, saying whether the buses are worth naming.
- Code writes every word: the reminder from the ronda's hour and public place, and the bus line
  from what `get_next_buses` found. The bus line passes the word gates on its own first, and is
  left out when it doesn't; then the whole message passes every gate (`gates.REMINDER`: hours,
  disclosure, no emoji, voseo, no money, public place; not the routine one, as it answers the
  person's own "voy").
- Without a reminder from the model (no model, an error, a timeout, the turn cap, or no call),
  code sends it without the bus line and a `note` step says why: a reminder is never late and
  never waits for a bus.

When: the hourly dispatcher's run inside the hour before the meeting's `slot.hour` (a meeting
with no hour gets none), inside the hours gate, once per ronda and week (the run is claimed in a
transaction; a failed one may be claimed again). `force` (the admin's `run_job`) skips the timing
and the claim, never the switch or the gates.

Where things live: `agent_runs/{rondaId}_{week}_dayof`, the run's trace, as every organiser run;
each message is a `message` step ("Salió" or "Frenado"), and the acta gets a line per tool call.
"""

import logging
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timedelta

from pydantic import Field

import mvd_buses
import rain
import rsvp
from organiser import gates, moves, outbox
from organiser import tools as organiser_tools
from organiser.agent import DONE, FAILED, run_agent
from organiser.model import ModelClient, ModelUnavailable, from_environment
from organiser.tools import Args, Meeting, Result, Toolbox
from organiser.trace import Trace

log = logging.getLogger(__name__)

JOB = "day_of"
SWITCH = "dayOfReminder"
"""`rondas/{id}.dayOfReminder`: the admin's switch, on unless it is `false`."""

WITHIN = organiser_tools.NEXT_BUSES_WITHIN
"""The reminder goes out this close to the meeting's start, and no earlier."""
MAX_STEPS = 5
"""Model turns: the buses, the reminder, the acta line, the last words, and one retry."""
MODEL_TIMEOUT = 20
"""Seconds per model request: the meeting is within the hour, and code has the plain reminder."""

SENT, NOT_SENT = "sent", "notSent"
COUNTS = ("rondas", "off", "held", "already", SENT, NOT_SENT, "failed")

SYSTEM = """Sos el organizador de Ronda, un programa que ayuda a grupos de vecinos que se \
juntan todas las semanas. Hacés solo logística: horarios, lugares y lluvia. No decidís nada \
por los vecinos.

Tu tarea ahora: la reunión es dentro de la hora y hay que mandarles el recordatorio a los que \
dijeron que van.
1. Mirá los próximos ómnibus con get_next_buses, una sola vez.
2. Llamá send_reminder una sola vez. Poné include_buses en true si get_next_buses trajo \
ómnibus que llegan antes de la reunión; si no trajo ninguno, o falló, en false. El texto lo \
escribe Ronda: vos solo decidís si van los ómnibus.
3. Dejá una sola línea en el acta con log_acta, en tercera persona ("Mandó…"), y terminá con \
una frase.

Reglas: cada herramienta lleva un reason corto y concreto. Sin Markdown y sin emoji. Nada de \
plata. Escribí en voseo rioplatense."""


class ReminderArgs(Args):
    include_buses: bool = Field(
        description="true para nombrar los próximos ómnibus que trajo get_next_buses."
    )


@dataclass
class ReminderToolbox(Toolbox):
    """`get_next_buses`, `send_reminder` and `log_acta`; remembers whether it sent."""

    sent: dict[str, int] | None = None
    """How many went out and were held, once the reminder went; None until then."""


def reminder_text(meeting: Meeting) -> str:
    """ "Hoy nos vemos a las 16:00 en la Plaza Gomensoro.": the hour and the ronda's public
    place, never an address."""
    place = f" en {meeting.place.name}" if meeting.place else ""
    return f"Hoy nos vemos {meeting.at}{place}."


def bus_line(found: mvd_buses.NextBuses) -> str:
    """ "Próximos ómnibus en 26 de Marzo y Jose Ellauri, según la Intendencia: el 191 en 6
    minutos, el 192 en 15." The comma after the stop keeps its street from reading as an
    address to the gate."""
    first, *rest = found.arrivals
    unit = "minuto" if first.minutes == 1 else "minutos"
    listed = ", ".join(
        [f"el {first.line} en {first.minutes} {unit}"]
        + [f"el {a.line} en {a.minutes}" for a in rest]
    )
    return f"Próximos ómnibus en {found.stop.name}, según la Intendencia: {listed}."


def send_reminder(box: ReminderToolbox, args: ReminderArgs) -> Result:
    if box.sent is not None:
        return organiser_tools._refused("Ya mandó el recordatorio de hoy.")
    sent = deliver(box, include_buses=args.include_buses)
    with_buses = " con los próximos ómnibus" if sent["buses"] else ""
    summary = f"Les recordó la reunión de hoy a {sent['sent']}{with_buses}."
    if sent["held"]:
        summary += f" Frenó {sent['held']}."
    return Result(sent, summary, "ok" if sent["sent"] or not sent["held"] else "held")


REMINDER_TOOLS = {
    "get_next_buses": organiser_tools.NEXT_BUSES_TOOL,
    "send_reminder": (
        "Les manda el recordatorio de hoy a los que dijeron que van; con include_buses en true "
        "nombra los próximos ómnibus que trajo get_next_buses. Una sola vez.",
        ReminderArgs,
        send_reminder,
    ),
    "log_acta": organiser_tools.TOOLS["log_acta"],
}


def deliver(box: ReminderToolbox, *, include_buses: bool) -> dict[str, int]:
    """Sends the reminder to every member who said "voy", through the gates; the bus line only
    when asked for, found, and clean by the word gates."""
    meeting = box.meeting
    words = reminder_text(meeting)
    buses = 0
    if include_buses and box.next_buses is not None:
        line = bus_line(box.next_buses)
        verdict = gates.check_words(line)
        if verdict.allowed:
            words, buses = f"{words} {line}", 1
        else:
            box.trace.step("note", note=f"Dejó afuera los ómnibus: {verdict.reason}.")
    week = box.db.document(f"rondas/{meeting.ronda_id}/weeks/{meeting.week}").get()
    answers = dict((week.to_dict() or {}).get("rsvp", {})) if week.exists else {}
    members = rsvp.counted(rsvp._members(box.db, meeting.ronda_id))
    going = sorted(
        uid
        for uid, member in members.items()
        if answers.get(uid) == rsvp.YES and not rsvp._paused_on(member, meeting.day)
    )
    outcomes = {"sent": 0, "held": 0, "unreachable": 0, "skipped": 0}
    for uid, name in rsvp._first_names(box.db, going).items():
        draft = outbox.prepare(
            box.db,
            outbox.Recipient(uid, name),
            title=rsvp.ronda_line(meeting.ronda),
            text=words,
            kind=gates.REMINDER,
            week=meeting.week,
            now=box.now,
            place=meeting.place,
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
        outcomes[outcome] += 1
    box.sent = {**outcomes, "buses": buses, "going": len(going)}
    return box.sent


def run_day_of(
    db,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
    force: bool = False,
    model: ModelClient | None = None,
    buses: mvd_buses.CityBuses | None = None,
) -> dict:
    """Sends the day-of reminder of every ronda not switched off whose meeting starts within
    the hour, once per meeting. `buses` stands in for the Intendencia's API (else from the
    function's secrets). Returns counts."""
    import httpx

    counts = dict.fromkeys(COUNTS, 0)
    here = rsvp.local(now)
    models: list[ModelClient] = [model] if model else []

    def get_model() -> ModelClient:
        if not models:
            models.append(from_environment(timeout=MODEL_TIMEOUT))
        return models[0]

    with httpx.Client() as http:
        city = buses or mvd_buses.from_environment(http)
        for snapshot in db.collection("rondas").stream():
            ronda = snapshot.to_dict()
            if ronda.get("status") not in rsvp.OPEN_STATUSES:
                continue
            counts["rondas"] += 1
            if ronda.get(SWITCH) is False:
                counts["off"] += 1
                continue
            hour = rsvp.meeting_hour(ronda)
            if hour is None:
                continue
            day = rsvp.next_meeting(ronda["slot"]["day"], here.date())
            start = datetime.combine(day, datetime.strptime(hour, "%H:%M").time(), here.tzinfo)
            if not (force or timedelta(0) < start - here <= WITHIN):
                continue
            if not rsvp.inside_gate(now):
                counts["held"] += 1
                continue
            ronda_id, week = snapshot.id, rsvp.iso_week(day)
            run_id = f"{ronda_id}_{week}_dayof"
            if force:
                run_id += f"_{here:%Y%m%dT%H%M}"
            elif not rsvp._in_transaction(db, rain._claim(db.document(f"agent_runs/{run_id}"))):
                counts["already"] += 1
                continue
            lat, lng = rain._location(ronda)
            meeting = Meeting(
                ronda_id=ronda_id, ronda=ronda, day=day, hour=hour, week=week, lat=lat, lng=lng
            )
            trace = Trace(db, run_id, ronda_id=ronda_id, week=week, now=now)
            try:
                outcome = remind_ronda(
                    db, meeting, trace, now, get_model, city, send, app_url, force
                )
                counts[outcome] += 1
            except Exception as error:
                log.error("day_of %s failed: %s", ronda_id, type(error).__name__)
                trace.step("stop", why=f"falló ({type(error).__name__})", model="")
                trace.finish(FAILED)
                counts["failed"] += 1
    log.info("day_of: %s", counts)
    return counts


def remind_ronda(
    db,
    meeting: Meeting,
    trace: Trace,
    now: datetime,
    get_model: Callable[[], ModelClient],
    buses: mvd_buses.CityBuses | None,
    send,
    app_url: str,
    force: bool,
) -> str:
    """One ronda's reminder, from the start of its run to its end: the model's, or code's
    without buses when the model didn't send it. Returns `SENT` when at least one went out."""
    box = ReminderToolbox(
        db=db,
        now=now,
        meeting=meeting,
        weather=None,
        send=send,
        app_url=app_url,
        trace=trace,
        host=outbox.Recipient("", "", outbox.HOST),
        host_fallback=False,
        covered={},
        tools=REMINDER_TOOLS,
        buses=buses,
    )
    try:
        model = get_model()
    except ModelUnavailable as error:
        trace.start(job=JOB, model="", forced=force)
        note = f"no hay modelo ({error})"
    else:
        box.model_name = lambda: model.name
        trace.start(job=JOB, model=model.name, forced=force)
        try:
            outcome = run_agent(
                model=model,
                toolbox=box,
                system=SYSTEM,
                task=task(meeting, now),
                trace=trace,
                max_steps=MAX_STEPS,
            )
        except Exception as error:
            # The reminder still goes: a broken run never keeps it from the members.
            log.error(
                "day_of %s: the model's run failed: %s", meeting.ronda_id, type(error).__name__
            )
            note = f"falló ({type(error).__name__})"
        else:
            note = (
                outcome.note if outcome.status == DONE else f"el modelo terminó ({outcome.status})"
            )
    if box.sent is None:
        trace.step("note", note=f"Ronda mandó el recordatorio sin los ómnibus: {note}.")
        sent = deliver(box, include_buses=False)
    else:
        sent = box.sent
    # Done either way, so no later run claims it again and sends twice; the note says how.
    trace.finish(DONE, note)
    return SENT if sent["sent"] else NOT_SENT


def task(meeting: Meeting, now: datetime) -> str:
    """What the model is told: the meeting and the time, no names, no addresses."""
    here = rsvp.local(now)
    pretext = rsvp.PRETEXT_LABELS.get(meeting.ronda.get("pretext"), "")
    place = f", en {meeting.place.name}" if meeting.place else ""
    return (
        f"Ronda: {pretext}.\n"
        f"Reunión: hoy {meeting.day.isoformat()} {meeting.at}{place}.\n"
        f"Ahora: {here:%H:%M}."
    )
