"""A move the organiser proposes to a ronda's host for one meeting, and the exact message each
option sends the members (docs/PRODUCT.md § Organiser agent, "Rain").

`rondas/{rondaId}/moves/{isoWeek}`, one per meeting, read by its host only (firestore.rules):
week, date, hour, hostUid, hostName, hostFallback (no `hosts.anfitrion` yet, so the first
active member), title and body (the push to the host, without the introduction), runId,
forecast {rainProbability, rainMm, gustsKmh}, options [{id, label, message, placeId?,
placeName?, date?}], recipients (how many members the pick reaches), deadline (21:00 the
evening before), status (`pending` | `decided` | `expired`), createdAt; once decided, choice,
decidedAt, sent and held.

Every word here is written in code, never by the model: the host reads, before choosing, the
message the members will get, and the gates check it again when it goes.
"""

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta

import rsvp
from organiser.weather import SOURCE, Forecast

COVERED = "covered"
POSTPONE = "postpone"
AS_IS = "asIs"
CHOICES = (COVERED, POSTPONE, AS_IS)

PENDING = "pending"
DECIDED = "decided"
EXPIRED = "expired"

DEADLINE_HOUR = 21
"""Without an answer by 21:00 the evening before, the plan stays as it is."""

GUSTS_WORTH_SAYING = 40
"""Gusts below this many km/h go unmentioned."""

MOVE_TYPE = "move"
"""`data.type` of the push to the host."""
AGENT_TYPE = "agent"
"""`data.type` of a message from the organiser to members."""


@dataclass(frozen=True)
class CoveredPlace:
    """A public place with a roof near the ronda (`places/{id}`): `name` carries its article
    ("el Salón Comunal de Solymar Sur") so the sentences read right."""

    id: str
    name: str


def weekday(day: date) -> str:
    """ "jueves"."""
    return rsvp.DAY_LABELS[rsvp.DAYS[day.weekday()]].lower()


def towards(name: str) -> str:
    """ "Al Salón…" for "el Salón…", "A la Biblioteca…" for "la Biblioteca…"."""
    if name.startswith("el "):
        return f"Al {name[3:]}"
    return f"A {name}"


def lower_first(words: str) -> str:
    """ "Al Salón Comunal" → "al Salón Comunal": a label in the middle of a sentence."""
    return words[:1].lower() + words[1:]


def deadline(meeting: date) -> datetime:
    """21:00 in Montevideo the evening before `meeting`."""
    day = meeting - timedelta(days=1)
    return datetime.combine(day, time(DEADLINE_HOUR), tzinfo=rsvp.MONTEVIDEO)


def host_message(meeting: date, hour: int, forecast: Forecast) -> tuple[str, str]:
    """The push to the host: "El jueves puede llover" / "Jueves 16:00 · lluvia 80%. …"."""
    title = f"El {weekday(meeting)} puede llover"
    body = f"{weekday(meeting).capitalize()} {hour:02d}:00 · lluvia {forecast.rain_probability}%."
    if forecast.gusts_kmh >= GUSTS_WORTH_SAYING:
        body += f" Ráfagas de {forecast.gusts_kmh} km/h."
    return title, f"{body} Pronóstico de {SOURCE}."


def options(
    meeting: date,
    hour: int,
    host_name: str,
    covered: CoveredPlace | None,
    postpone_to: date | None,
) -> list[dict]:
    """The host's choices, each with the one message the members get if it is picked. "Vamos
    igual" is always there, last."""
    day, at = weekday(meeting), f"{hour:02d}:00"
    decided = f"Lo decidió {host_name}." if host_name else "Lo decidió quien abre la ronda."
    choices = []
    if covered is not None:
        choices.append(
            {
                "id": COVERED,
                "label": towards(covered.name),
                "message": f"Por la lluvia, el {day} nos vemos en {covered.name} a las {at}. "
                + decided,
                "placeId": covered.id,
                "placeName": covered.name,
            }
        )
    if postpone_to is not None:
        later = weekday(postpone_to)
        choices.append(
            {
                "id": POSTPONE,
                "label": f"Pasarla al {later}",
                "message": f"Por la lluvia, la ronda del {day} pasa al {later} a las {at}, "
                f"en el mismo lugar. {decided}",
                "date": postpone_to.isoformat(),
            }
        )
    choices.append(
        {
            "id": AS_IS,
            "label": "Vamos igual",
            "message": f"Puede llover, pero el {day} vamos igual, a las {at} como siempre. "
            + decided,
        }
    )
    return choices
