"""Three invented demo rondas for the card eval, all meeting in ISO week 2026-W45, built on the
functions' own Firestore stand-in and the rain check's fixtures (`tests.organiser_fakes`).
Every person, place and address is invented.

- `mate`: Thursday 16:00 at the quiosco, a host (Mirta), a newcomer (Facu joined on Sunday)
  and a después at Mirta's home (its address must never reach the card).
- `truco`: Tuesday 19:30 at the club, a host (Jorge) and one offer on the bench.
- `futbol5`: Saturday 10:00, no host set yet, nothing else: the card should carry little.
"""

from datetime import UTC, datetime

from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import JOINED, RONDA, WEEK, at, documents

WEEK_ID = WEEK
MON_10 = at(2, 10)
"""Monday 2026-11-02 10:00 in Montevideo, when the job runs for every ronda."""

RONDAS = ("mate", "truco", "futbol5")


def _copy(docs: dict[str, dict], ronda_id: str) -> dict[str, dict]:
    """The fixture ronda's documents under another id."""
    out = {}
    for path, fields in docs.items():
        if path.startswith(f"rondas/{RONDA}"):
            out[path.replace(RONDA, ronda_id, 1)] = dict(fields)
        elif not path.startswith("rondas/"):
            out[path] = dict(fields)
    return out


def database() -> FakeFirestore:
    """All three rondas, with the switch on."""
    base = documents(agentCard=True, hosts={"anfitrion": "demo-101", "anfitrionName": "Mirta"})
    docs: dict[str, dict] = {}

    mate = _copy(base, "mate")
    mate["rondas/mate/members/demo-104"]["joinedAt"] = at(1, 12)
    mate[f"rondas/mate/despues/{WEEK}"] = {
        "week": WEEK,
        "status": "set",
        "kind": "home",
        "what": "bizcochos",
        "homeName": "Mirta",
        "address": "Av. Central 1234",
    }
    docs.update(mate)

    truco = _copy(base, "truco")
    truco["rondas/truco"].update(
        {
            "pretext": "truco",
            "slot": {"day": "tue", "time": "evening", "hour": "19:30"},
            "place": {"name": "el Club Lagomar", "landmark": "", "lat": -34.82, "lng": -55.91},
            "hosts": {"anfitrion": "demo-102", "anfitrionName": "Jorge"},
        }
    )
    truco[f"rondas/truco/bench/{WEEK}"] = {
        "offers": [{"offerId": f"truco_{WEEK}_1", "uid": "demo-900", "status": "pending"}]
    }
    docs.update(truco)

    futbol = _copy(base, "futbol5")
    futbol["rondas/futbol5"].update(
        {
            "pretext": "futbol5",
            "slot": {"day": "sat", "time": "morning", "hour": "10:00"},
            "place": {"name": "la cancha del parque", "landmark": "", "lat": -34.81, "lng": -55.9},
        }
    )
    futbol["rondas/futbol5"].pop("hosts", None)
    docs.update(futbol)

    for uid in ("demo-101", "demo-102", "demo-103", "demo-104"):
        docs.setdefault(f"users/{uid}", {"firstName": uid, "joinedAt": JOINED})
    return FakeFirestore(docs)


def now() -> datetime:
    return MON_10.astimezone(UTC)
