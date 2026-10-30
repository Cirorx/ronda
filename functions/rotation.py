"""The monthly turns of who opens and who closes: "Este mes abre Jorge y cierra Ana", with the
months ahead (docs/PRODUCT.md § The weekly loop, "Hosts"; the `assign_hosts` part of #50).

A plain code job with one fixed rule, never the model:
- each month the cola becomes the anfitrión, and the next member in the cycle closes;
- the cycle is the ronda's active members by when they joined (a paused member is skipped
  while paused, and one who left drops out);
- the admin's pick on `/admin/rondas` (hosts.set_setup) is the override: it stamps the month
  (`hosts.month`) and the turns go on from it. The job only moves a ronda whose stamp is behind
  the current month in Montevideo, and never rewrites a stamped month.
Nothing starts the turns but the admin: a ronda with no anfitrión and cola is left alone, as
approval leaves it. A ronda with hosts set before this existed gets the current month stamped
and its turns written, with no change of hosts.

`run_assign_hosts(db, now)` is the job (`jobs.JOBS["assign_hosts"]`). It sends no message: the
card shows the turns months ahead, and the acta says who opens this month.

On `rondas/{id}` (docs/ARCHITECTURE.md § Data model): `hosts {anfitrion, cola, anfitrionName,
colaName, month}` and `turns [{month, anfitrion, anfitrionName, cola, colaName}]`, this month
first, then the next `MONTHS_SHOWN - 1`.
"""

from datetime import datetime

import rsvp
from organiser.trace import RULE, Trace

JOB = "assign_hosts"

MONTHS_SHOWN = 3
"""How many months of turns the ronda carries: this one and the next two."""


def month_of(now: datetime) -> str:
    """ "2026-11": the month in Montevideo."""
    return f"{rsvp.local(now):%Y-%m}"


def add_months(month: str, count: int) -> str:
    """ "2026-12" for ("2026-11", 1)."""
    year, number = (int(part) for part in month.split("-"))
    index = year * 12 + number - 1 + count
    return f"{index // 12:04d}-{index % 12 + 1:02d}"


def cycle(members: dict[str, dict]) -> list[str]:
    """Who takes turns: the active members, by when they joined."""
    active = [uid for uid, member in members.items() if member.get("state", "active") == "active"]
    return sorted(active, key=lambda uid: (str(members[uid].get("joinedAt", "")), uid))


def next_pair(order: list[str], pair: tuple[str, str]) -> tuple[str, str]:
    """The next month's `(anfitrión, cola)`: the cola opens and the next in `order` closes. With
    fewer than two to take turns, the pair stays."""
    if len(order) < 2:
        return pair
    anfitrion, cola = pair
    if cola in order:
        opens = cola
    elif anfitrion in order:
        opens = order[(order.index(anfitrion) + 1) % len(order)]
    else:
        opens = order[0]
    return opens, order[(order.index(opens) + 1) % len(order)]


def turns(db, order: list[str], pair: tuple[str, str], month: str) -> list[dict]:
    """`MONTHS_SHOWN` turns from `month`, the first being `pair`, each with first names."""
    pairs = [pair]
    while len(pairs) < MONTHS_SHOWN:
        pairs.append(next_pair(order, pairs[-1]))
    names = rsvp._first_names(db, {uid for p in pairs for uid in p})
    return [
        {
            "month": add_months(month, offset),
            "anfitrion": anfitrion,
            "anfitrionName": names[anfitrion],
            "cola": cola,
            "colaName": names[cola],
        }
        for offset, (anfitrion, cola) in enumerate(pairs)
    ]


def run_assign_hosts(db, now: datetime) -> dict:
    """The hourly turns job: moves every ronda whose hosts' month is behind to this month's
    pair, and stamps the month on hosts set before the turns existed. Returns counts."""
    counts = {"rondas": 0, "rotated": 0, "stamped": 0}
    month = month_of(now)
    for snapshot in db.collection("rondas").stream():
        ronda = snapshot.to_dict()
        hosts = ronda.get("hosts") or {}
        if ronda.get("status") not in rsvp.OPEN_STATUSES:
            continue
        if not (hosts.get("anfitrion") and hosts.get("cola")):
            continue
        counts["rondas"] += 1
        stamped = hosts.get("month")
        if isinstance(stamped, str) and stamped >= month:
            continue
        ronda_id = snapshot.id
        order = cycle(rsvp.counted(rsvp._members(db, ronda_id)))
        pair = (hosts["anfitrion"], hosts["cola"])
        if isinstance(stamped, str):
            while stamped < month:
                pair = next_pair(order, pair)
                stamped = add_months(stamped, 1)
        ahead = turns(db, order, pair, month)
        db.document(f"rondas/{ronda_id}").update({"hosts": dict(ahead[0]), "turns": ahead})
        if not isinstance(hosts.get("month"), str):
            counts["stamped"] += 1
            continue
        trace = Trace(
            db,
            f"{ronda_id}_{month}_hosts",
            ronda_id=ronda_id,
            week=rsvp.iso_week(rsvp.local(now).date()),
            now=now,
        )
        trace.start(job=JOB, model="", forced=False)
        summary = (
            f"Este mes abre {ahead[0]['anfitrionName']} y cierra {ahead[0]['colaName']}. "
            "Así toca por turno."
        )
        trace.step("note", note=summary)
        trace.acta(JOB, summary, RULE)
        trace.finish("done")
        counts["rotated"] += 1
    return counts
