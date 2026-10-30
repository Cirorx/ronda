"""The rain decision (docs/PRODUCT.md § Organiser agent, "Rain").

The evening before each meeting, at 18:00 in Montevideo, the organiser agent looks at the
forecast for the meeting's hours; when rain is likely it checks the sunset, the last bus and
who's coming, and proposes options to the host only: a covered public place nearby, another
day, or going anyway, each with the exact message the members will get. The host's pick sends
that one message to the members; without a pick by 21:00 the plan stays as it is.

- `run_rain_check(db, now, send=...)`: the job (`jobs.JOBS["rain_check"]`), hourly from the
  dispatcher and by name from the admin's `run_job`. Each ronda is checked once a week: the run
  `agent_runs/{rondaId}_{week}_rain` is claimed in a transaction (a failed run may be claimed
  again on the next hour). `force` (the admin's "Correr ahora", or a test at a set `now`)
  skips the timing and the claim, and gets a run of its own; never a gate. Each run also lets a
  proposal nobody answered expire at 21:00.
- `answer_move(db, uid, ronda_id, week, choice, now, send=...)`: the `answer_move` callable's
  body, for the host's pick.

The host is `hosts.anfitrion` while that member is in the ronda; until #47 sets hosts, the first
active member (by joining time) stands in, and the trace and the move say so (`hostFallback`).
The model is built from the environment only when a ronda is due, so a dry hour costs nothing;
tests pass a scripted model and a fake forecast.
"""

import logging
from collections.abc import Callable
from datetime import date, datetime, timedelta

import rsvp
from organiser import gates, moves, outbox
from organiser.agent import FAILED, STOPPED, run_agent
from organiser.model import ModelClient, ModelUnavailable, from_environment
from organiser.tools import Meeting, Toolbox
from organiser.trace import HOST, Trace
from organiser.weather import OpenMeteo, Weather

log = logging.getLogger(__name__)

JOB = "rain_check"
RAIN_CHECK_HOUR = 18
"""The evening before the meeting (Wednesday 18:00 for a Thursday ronda)."""

BAND_HOURS = {"morning": 10, "afternoon": 16, "evening": 19}
"""When a meeting starts, by its slot's time band, until a host sets an hour."""

CIUDAD_DE_LA_COSTA = (-34.83, -55.96)
"""Where the forecast is read when neither the ronda's place nor its barrio is known."""

SYSTEM = """Sos el organizador de Ronda, un programa que ayuda a grupos de vecinos que se \
juntan todas las semanas. Hacés solo logística: horarios, lugares y lluvia. Las decisiones \
las toma quien abre la ronda (el anfitrión), no vos.

Tu tarea ahora: mañana hay reunión y puede llover.
1. Mirá el pronóstico de la reunión con get_forecast.
2. Si la lluvia es probable (rainLikely), mirá a qué hora atardece (get_sunset), el último \
ómnibus (get_last_bus) y cuántos van (count_rsvps). Después proponele al anfitrión qué hacer \
con propose_move: un lugar techado de la lista si hay, y otro día si tiene sentido (que no \
termine de noche ni después del último ómnibus). Seguir igual va siempre como opción.
3. Si la lluvia no es probable, no propongas nada.
4. Al final dejá una sola línea en el acta con log_acta, en tercera persona, como las \
otras ("Propuso…", "Miró…"), y terminá con una frase.

Reglas: cada herramienta lleva un reason corto y concreto. No les escribas a los miembros: \
el anfitrión decide y Ronda les avisa. Sin Markdown y sin emoji. Escribí en voseo rioplatense."""


class MoveError(Exception):
    """A pick the callable refuses; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


# --- The job ------------------------------------------------------------------------------


def run_rain_check(
    db,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
    force: bool = False,
    model: ModelClient | None = None,
    weather: Weather | None = None,
) -> dict:
    """Checks every ronda whose meeting is tomorrow, from 18:00 to 21:00 in Montevideo (any
    open ronda's next meeting with `force`), and lets unanswered proposals expire. Returns
    counts."""
    import httpx

    counts = {"rondas": 0, "checked": 0, "already": 0, "failed": 0, "expired": 0}
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
            ronda_id = snapshot.id
            day = rsvp.next_meeting(ronda["slot"]["day"], here.date())
            week = rsvp.iso_week(day)
            counts["expired"] += _expire(db, ronda_id, week, now)
            due = (
                here.date() == day - timedelta(days=1)
                and RAIN_CHECK_HOUR <= here.hour < moves.DEADLINE_HOUR
            )
            if not (force or due):
                continue
            run_id = f"{ronda_id}_{week}_rain"
            if force:
                run_id += f"_{here:%Y%m%dT%H%M}"
            elif not rsvp._in_transaction(db, _claim(db.document(f"agent_runs/{run_id}"))):
                counts["already"] += 1
                continue
            lat, lng = _location(ronda)
            meeting = Meeting(
                ronda_id=ronda_id,
                ronda=ronda,
                day=day,
                hour=BAND_HOURS.get(ronda["slot"].get("time"), BAND_HOURS["afternoon"]),
                week=week,
                lat=lat,
                lng=lng,
            )
            trace = Trace(db, run_id, ronda_id=ronda_id, week=week, now=now)
            try:
                status = check_ronda(
                    db, meeting, trace, now, get_model, forecast, send, app_url, force
                )
            except Exception as error:
                log.error("rain_check %s failed: %s", ronda_id, type(error).__name__)
                trace.step("stop", why=f"falló ({type(error).__name__})", model="")
                trace.finish(FAILED)
                status = FAILED
            counts["failed" if status == FAILED else "checked"] += 1
    log.info("rain_check: %s", counts)
    return counts


def _claim(run_ref) -> Callable:
    def claim(transaction) -> bool:
        snapshot = run_ref.get(transaction=transaction)
        if snapshot.exists and (snapshot.to_dict() or {}).get("status") != FAILED:
            return False
        transaction.set(run_ref, {"status": "running"}, merge=True)
        return True

    return claim


def check_ronda(
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
    """One ronda's rain check, from the start of its run to its end; returns the run's
    status."""
    try:
        model = get_model()
    except ModelUnavailable as error:
        trace.start(job=JOB, model="", forced=force)
        trace.step("stop", why=f"no hay modelo ({error})", model="")
        trace.finish(FAILED)
        return FAILED
    trace.start(job=JOB, model=model.name, forced=force)
    host, fallback = _host(db, meeting.ronda_id, meeting.ronda)
    if host is None:
        trace.step("stop", why="la ronda no tiene miembros activos", model="")
        trace.finish(STOPPED)
        return STOPPED
    if fallback:
        missing = (
            "El anfitrión no está activo en la ronda"
            if (meeting.ronda.get("hosts") or {}).get("anfitrion")
            else "No hay anfitrión asignado"
        )
        trace.step(
            "note",
            note=f"{missing}: la propuesta iría a {host.first_name}, el primer miembro activo.",
        )
    covered = _covered_places(db, meeting.ronda.get("barrio", ""))
    toolbox = Toolbox(
        db=db,
        now=now,
        meeting=meeting,
        weather=weather,
        send=send,
        app_url=app_url,
        trace=trace,
        host=host,
        host_fallback=fallback,
        covered=covered,
        model_name=lambda: model.name,
    )
    outcome = run_agent(
        model=model, toolbox=toolbox, system=SYSTEM, task=task(meeting, covered, now), trace=trace
    )
    trace.finish(outcome.status, outcome.note)
    return outcome.status


def task(meeting: Meeting, covered: dict[str, moves.CoveredPlace], now: datetime) -> str:
    """What the model is told about this ronda: no names, no addresses."""
    here = rsvp.local(now)
    pretext = rsvp.PRETEXT_LABELS.get(meeting.ronda.get("pretext"), "")
    place = f", en {meeting.place.name}" if meeting.place else ""
    places = "\n".join(f"- {p.id}: {p.name}" for p in covered.values()) or "- ninguno"
    return (
        f"Ronda: {pretext}.\n"
        f"Reunión: {moves.weekday(meeting.day)} {meeting.day.isoformat()} a las "
        f"{meeting.hour:02d}:00{place}.\n"
        f"Ahora: {moves.weekday(here.date())} {here.date().isoformat()} {here:%H:%M}.\n"
        f"Lugares techados públicos cerca (id: nombre):\n{places}"
    )


def _location(ronda: dict) -> tuple[float, float]:
    place = ronda.get("place")
    if isinstance(place, dict) and isinstance(place.get("lat"), int | float):
        return float(place["lat"]), float(place["lng"])
    # The solver's barrio table; importing it loads OR-Tools, so only when a ronda is due.
    from proposals import BARRIOS

    if (centroid := BARRIOS.get(ronda.get("barrio"))) is not None:
        return centroid["lat"], centroid["lng"]
    return CIUDAD_DE_LA_COSTA


def _host(db, ronda_id: str, ronda: dict) -> tuple[outbox.Recipient | None, bool]:
    """The ronda's anfitrión, or the first active member standing in (`True`)."""
    members = rsvp.counted(rsvp._members(db, ronda_id))
    active = {uid: m for uid, m in members.items() if m.get("state", "active") == "active"}
    anfitrion = (ronda.get("hosts") or {}).get("anfitrion")
    if anfitrion in active:
        uid, fallback = anfitrion, False
    elif active:
        uid = min(active, key=lambda u: (str(active[u].get("joinedAt", "")), u))
        fallback = True
    else:
        return None, False
    name = rsvp._first_names(db, [uid])[uid]
    return outbox.Recipient(uid, name, outbox.HOST), fallback


def _covered_places(db, barrio: str) -> dict[str, moves.CoveredPlace]:
    """`places/{id}` with a roof, public, near `barrio`."""
    places = {}
    for snapshot in db.collection("places").stream():
        place = snapshot.to_dict()
        if (
            place.get("covered") is True
            and place.get("kind") == gates.PUBLIC
            and barrio in place.get("barrios", [])
        ):
            places[snapshot.id] = moves.CoveredPlace(snapshot.id, place["name"])
    return places


def _expire(db, ronda_id: str, week: str, now: datetime) -> int:
    """Lets the week's proposal expire once 21:00 the evening before has passed unanswered;
    returns 1 when it did."""
    move_ref = db.document(f"rondas/{ronda_id}/moves/{week}")

    def expire(transaction) -> dict | None:
        snapshot = move_ref.get(transaction=transaction)
        move = (snapshot.to_dict() or {}) if snapshot.exists else {}
        if move.get("status") != moves.PENDING:
            return None
        if rsvp.local(now) < moves.deadline(date.fromisoformat(move["date"])):
            return None
        transaction.update(move_ref, {"status": moves.EXPIRED, "expiredAt": now})
        return move

    move = rsvp._in_transaction(db, expire)
    if move is None:
        return 0
    trace = Trace(db, move["runId"], ronda_id=ronda_id, week=week, now=now)
    summary = (
        f"{move.get('hostName') or 'El anfitrión'} no eligió antes de las "
        f"{moves.DEADLINE_HOUR}: queda como está."
    )
    trace.step("host", choice="", resultSummary=summary)
    trace.acta("host_choice", summary)
    return 1


# --- The host's pick ----------------------------------------------------------------------


def answer_move(
    db,
    uid: str,
    ronda_id: str,
    week: str,
    choice: str,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
) -> dict:
    """Records the host's pick and sends its message to the members, once.

    A second call answers what the first did and sends nothing. After the deadline, or once
    the proposal expired, it refuses: the plan stays as it is.
    """
    move_ref = db.document(f"rondas/{ronda_id}/moves/{week}")
    snapshot = move_ref.get()
    if not snapshot.exists:
        raise MoveError("not-found", "no proposal for that week")
    move = snapshot.to_dict()
    if move.get("hostUid") != uid:
        raise MoveError("permission-denied", "only the host picks")
    if move.get("status") == moves.DECIDED:
        return _already(move)
    if move.get("status") == moves.EXPIRED or rsvp.local(now) >= moves.deadline(
        date.fromisoformat(move["date"])
    ):
        raise MoveError("failed-precondition", "the time to pick has passed")
    option = next((o for o in move.get("options", []) if o.get("id") == choice), None)
    if option is None:
        raise MoveError("invalid-argument", "not one of the options")

    def claim(transaction) -> bool:
        current = move_ref.get(transaction=transaction).to_dict() or {}
        if current.get("status") != moves.PENDING:
            return False
        transaction.update(move_ref, {"status": moves.DECIDED, "choice": choice, "decidedAt": now})
        return True

    if not rsvp._in_transaction(db, claim):
        return _already(move_ref.get().to_dict() or {})
    from google.cloud.firestore import DELETE_FIELD

    try:
        result = _send_choice(db, ronda_id, week, move, option, now, send, app_url)
    except Exception:
        move_ref.update(
            {"status": moves.PENDING, "choice": DELETE_FIELD, "decidedAt": DELETE_FIELD}
        )
        raise
    move_ref.update({"sent": result["sent"], "held": result["held"]})
    return {"status": moves.DECIDED, "choice": choice, **result}


def _already(move: dict) -> dict:
    return {
        "status": "already",
        "choice": move.get("choice", ""),
        "sent": move.get("sent", 0),
        "held": move.get("held", 0),
    }


def _send_choice(db, ronda_id, week, move, option, now, send, app_url) -> dict:
    ronda = db.document(f"rondas/{ronda_id}").get().to_dict() or {}
    meeting_day = date.fromisoformat(move["date"])
    host_name = move.get("hostName") or "El anfitrión"
    trace = Trace(db, move["runId"], ronda_id=ronda_id, week=week, now=now)
    trace.step("host", choice=option["id"], resultSummary=f"{host_name} eligió: {option['label']}.")
    trace.acta("host_choice", f"{host_name} eligió: {moves.lower_first(option['label'])}.", HOST)

    if option["id"] == moves.COVERED:
        place = gates.Place(option["placeName"])
        override = {"placeOverride": {"placeId": option["placeId"], "name": option["placeName"]}}
    else:
        own = ronda.get("place")
        place = gates.Place(own["name"]) if isinstance(own, dict) and own.get("name") else None
        override = {"dateOverride": option["date"]} if option["id"] == moves.POSTPONE else {}

    members = rsvp.counted(rsvp._members(db, ronda_id))
    uids = sorted(
        u
        for u, m in members.items()
        if u != move["hostUid"] and not rsvp._paused_on(m, meeting_day)
    )
    names = rsvp._first_names(db, uids)
    title = rsvp.ronda_line(ronda)
    outcomes: dict[str, int] = {}
    reasons: set[str] = set()
    for member_uid in uids:
        draft = outbox.prepare(
            db,
            outbox.Recipient(member_uid, names[member_uid]),
            title=title,
            text=option["message"],
            kind=gates.CHANGE,
            week=week,
            now=now,
            place=place,
        )
        outcome = outbox.deliver(
            db,
            trace,
            draft,
            send=send,
            data={"type": moves.AGENT_TYPE, "rondaId": ronda_id},
            link=app_url,
            now=now,
        )
        outcomes[outcome] = outcomes.get(outcome, 0) + 1
        if not draft.verdict.allowed:
            reasons.add(draft.verdict.reason)
    if override:
        db.document(f"rondas/{ronda_id}/weeks/{week}").set(override, merge=True)
    sent, held = outcomes.get("sent", 0), outcomes.get("held", 0)
    trace.acta(
        "send_member_push", f"Les avisó a {sent} en un solo mensaje: «{option['message']}»", HOST
    )
    if held:
        trace.acta(
            "send_member_push", f"Frenó el mensaje para {held}: {'; '.join(sorted(reasons))}.", HOST
        )
    return {"sent": sent, "held": held, "unreachable": outcomes.get("unreachable", 0)}
