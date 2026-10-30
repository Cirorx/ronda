"""The gates: rules in code that every message the organiser sends passes, whatever the model
wrote (docs/PRODUCT.md § Organiser agent). A message that fails one is held ("Frenado") with
the reason, and, when only the hour stopped it, the time it could go out.

In order:
1. `quiet_hours`: nothing goes out from 21:00 to 09:00 in Montevideo (the RSVP push's gate,
   `rsvp.inside_gate`).
2. `disclosure`: a person's first message from the organiser says it is a program
   ("Soy un programa"); the outbox adds the introduction, and this gate checks it is there.
3. `emoji`: none, in the title or the text.
4. `voseo`: no tú form (`text.tu_forms`, with its limits).
5. `money`: nothing that asks for or mentions money (`text.money`): Ronda never asks for it,
   and says so only in the terms and on the flyers. Held as "menciona plata".
6. `routine`: one routine message a week per member. The week's RSVP push ("¿Venís?") is that
   ronda's routine message, so a routine message from the organiser in the same week is held.
   A change the host decided (a rain move) and a proposal to the host are not routine.
7. `public_place`: the ronda itself only meets in public places. A message that sends people
   somewhere must name a public place, and its words must not look like a home or an address
   (`text.private_place`). A home is only for the después, which the organiser never sends.

`check_words` runs only the gates about words (3, 4, 5 and the address check of 7), for what
members read that isn't a message: the acta.
"""

from dataclasses import dataclass
from datetime import datetime, time, timedelta

import rsvp
from organiser import text

DISCLOSURE = "Soy un programa"

ROUTINE = "routine"
"""A message the organiser writes on its own: at most one a week per member."""
CHANGE = "change"
"""A change the host decided, sent to the members."""
HOST = "host"
"""A proposal to the host."""

PUBLIC = "public"
"""`places/{id}.kind` of a place the ronda itself may meet in."""


def introduction(first_name: str) -> str:
    """The organiser's first words to a person (docs/PRODUCT.md § Organiser agent)."""
    greeting = f"Hola, {first_name}." if first_name else "Hola."
    return (
        f"{greeting} {DISCLOSURE}. Ronda me usa para avisar horarios, lugares y lluvia. "
        "Las decisiones las toman ustedes. Nunca escribo de noche."
    )


@dataclass(frozen=True)
class Place:
    """Where a message sends people: a name and its kind."""

    name: str
    kind: str = PUBLIC


@dataclass(frozen=True)
class Outgoing:
    """One message to one person, with what the gates need to know about them."""

    title: str
    text: str
    kind: str
    introduced: bool
    """Whether the person already had a message from the organiser."""
    routine_used: bool = False
    """Whether the person already had this week's routine message."""
    place: Place | None = None


@dataclass(frozen=True)
class Verdict:
    """Whether a message may go out; if not, which gate held it and why (es-419, for the trace
    and the acta), and for the quiet hours when it could go out."""

    allowed: bool
    gate: str = ""
    reason: str = ""
    release_at: datetime | None = None


ALLOWED = Verdict(True)


def release_time(now: datetime) -> datetime:
    """The next 09:00 in Montevideo after `now`, when a message held at night may go out."""
    here = rsvp.local(now)
    day = here.date() if here.hour < rsvp.QUIET_UNTIL else here.date() + timedelta(days=1)
    return datetime.combine(day, time(rsvp.QUIET_UNTIL), tzinfo=rsvp.MONTEVIDEO)


def check_words(words: str) -> Verdict:
    """The gates about words alone: no emoji, voseo, no money, no home or address."""
    if found := text.emoji(words):
        return Verdict(False, "emoji", f"tiene un emoji ({found})")
    if found := text.tu_forms(words):
        return Verdict(False, "voseo", f"no está en voseo: «{found}»")
    if found := text.money(words):
        return Verdict(False, "money", f"menciona plata («{found}»)")
    if found := text.private_place(words):
        return Verdict(False, "public_place", f"parece una casa o una dirección: «{found}»")
    return ALLOWED


def check(message: Outgoing, now: datetime) -> Verdict:
    """Every gate, in order; the first that fails holds the message."""
    if not rsvp.inside_gate(now):
        return Verdict(False, "quiet_hours", "fuera de horario", release_time(now))
    if not message.introduced and DISCLOSURE not in message.text:
        return Verdict(False, "disclosure", "es el primer mensaje y no dice que es un programa")
    words = check_words(f"{message.title}\n{message.text}")
    if not words.allowed:
        return words
    if message.kind == ROUTINE and message.routine_used:
        return Verdict(False, "routine", "ya recibió el mensaje de rutina de esta semana")
    if message.place is not None and message.place.kind != PUBLIC:
        return Verdict(False, "public_place", f"{message.place.name} no es un lugar público")
    return ALLOWED
