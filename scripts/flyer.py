# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = [
#     "google-cloud-firestore>=2.21,<3",
#     "ortools==9.15.6755",
#     "protobuf==6.33.6",
#     "reportlab==5.0.1",
# ]
# ///
"""Make a tear-off flyer: its `flyers/{id}` document and a printable PDF of seven QR strips.

From the repo root, in the emulator:

    FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 uv run --python 3.13 scripts/flyer.py \\
        --lat -34.8285 --lng -55.9405 --label "Almacén, Gaviotas y Transversal" \\
        --slot sat-afternoon

and on the real project, with Application Default Credentials and no emulator host, the same
with `--project ronda-uy`. The project is otherwise GCLOUD_PROJECT, or the .firebaserc default.

`--lat`/`--lng` is where the flyer will hang. It picks the barrio (the nearest centroid), the
barrios within walking distance whose rondas the QR page shows (centroids within the solver's
ten blocks) and the bus stop, and is then dropped: the document never holds it. `--label` is
for the admin's scans-per-spot count and is never shown in public. The stop is the nearest one
unless `--stop` names another; the five nearest are printed with their last buses, since the
nearest can be a stop with three buses a day. The last bus of each day type is worked out here,
once, from the DNT timetable (`last_bus.py`) and stored on the document; the page never
computes it. `--gtfs` takes a downloaded zip instead of fetching the published one.

The QR points at `{base}/f/{id}`. The base defaults to the project's firebaseapp.com address,
the web app's sign-in domain, so [Quiero sumarme] signs in on the same site (docs/STACK.md §
Pilot builds).
"""

import argparse
import os
import re
import secrets
import sys
import tempfile
import urllib.request
from datetime import UTC, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import demo_data
import flyer_pdf
import last_bus
import seed

sys.path.append(str(demo_data.ROOT / "solver"))
from ronda_solver.demo import DEMO_BARRIOS
from ronda_solver.geo import blocks_between
from ronda_solver.rules import MAX_WALK_BLOCKS

URUGUAY = ZoneInfo("America/Montevideo")
ID_ALPHABET = "23456789abcdefghjkmnpqrstuvwxyz"
"""Lowercase letters and digits without 0/o, 1/l/i: read aloud or typed from a strip, they
can't be mistaken. functions/cerca_tuyo.py accepts exactly eight of `[a-z0-9]`."""
ID_LENGTH = 8
SLOT = re.compile(r"(mon|tue|wed|thu|fri|sat|sun)-(morning|afternoon|evening)")

BARRIO_NAMES = {
    "shangrila": "Shangrilá",
    "san-jose-de-carrasco": "San José de Carrasco",
    "lagomar-sur": "Lagomar Sur",
    "lagomar-norte": "Lagomar Norte",
    "solymar-sur": "Solymar Sur",
    "solymar-norte": "Solymar Norte",
    "lomas-de-solymar": "Lomas de Solymar",
    "el-pinar-sur": "El Pinar Sur",
    "el-pinar-norte": "El Pinar Norte",
}
"""The app's barrio names (lib/l10n/arb/app_es.arb)."""

HEADLINES = {
    "mate": "¿Te sumás a un mate?",
    "truco": "¿Te sumás a un truco?",
    "futbol5": "¿Te sumás a un fútbol 5?",
    "caminata": "¿Te sumás a una caminata?",
}
DAYS = {
    "mon": "Los lunes",
    "tue": "Los martes",
    "wed": "Los miércoles",
    "thu": "Los jueves",
    "fri": "Los viernes",
    "sat": "Los sábados",
    "sun": "Los domingos",
}
BANDS = {"morning": "de 9 a 12", "afternoon": "de 14 a 18", "evening": "de 19 a 21"}


def flyer_text(pretext: str, slot: str | None, barrio: str) -> flyer_pdf.FlyerText:
    """The flyer's words, docs/PRODUCT.md § Flyers: what, when and where (the barrio, never a
    spot), who, and that nothing is needed."""
    if slot:
        day, _, band = slot.partition("-")
        when = f"{DAYS[day]} {BANDS[band]}"
    else:
        when = "Una vez por semana"
    team = "10" if pretext == "futbol5" else "5 o 6"
    return flyer_pdf.FlyerText(
        headline=HEADLINES[pretext],
        what=f"Grupos de {team} vecinos que se juntan una vez por semana, "
        "siempre en lugares públicos.",
        facts=(
            f"{when}, en {BARRIO_NAMES[barrio]}",
            f"{team} vecinos de todas las edades",
            "No hace falta traer nada",
        ),
        tear="Arrancá una tira y escaneala.",
        money="Ronda nunca pide plata.",
    )


def barrio_at(spot: tuple[float, float]) -> str:
    """The barrio whose centroid is nearest `spot`."""
    return min(DEMO_BARRIOS, key=lambda barrio: blocks_between(spot, DEMO_BARRIOS[barrio]))


def near_barrios(spot: tuple[float, float], barrio: str) -> list[str]:
    """`barrio`, then every other barrio whose centroid is within walking distance of `spot`
    (the solver's ten blocks), nearest first."""
    others = sorted(
        (b for b in DEMO_BARRIOS if b != barrio),
        key=lambda b: blocks_between(spot, DEMO_BARRIOS[b]),
    )
    return [barrio] + [
        b for b in others if blocks_between(spot, DEMO_BARRIOS[b]) <= MAX_WALK_BLOCKS
    ]


def flyer_document(
    *,
    label: str,
    pretext: str,
    slot: str | None,
    barrio: str,
    near: list[str],
    stop: last_bus.Stop,
    buses: dict[str, dict | None],
    now: datetime,
) -> dict:
    """`flyers/{id}`: no coordinates, no person. `kind` tells it from an "Un mate de más" flyer
    in the same collection; `scans` starts at zero for flyer_landing."""
    return {
        "kind": "tearOff",
        "label": label,
        "pretext": pretext,
        "slot": slot,
        "barrio": barrio,
        "nearBarrios": near,
        "stop": {"id": stop.id, "name": stop.name},
        "lastBus": buses,
        "scans": 0,
        "createdAt": now,
    }


def new_id() -> str:
    return "".join(secrets.choice(ID_ALPHABET) for _ in range(ID_LENGTH))


def create(client, document: dict, attempts: int = 5) -> str:
    """Creates `flyers/{id}` under a fresh id, never over an existing flyer. Returns the id."""
    from google.api_core.exceptions import AlreadyExists

    for _ in range(attempts):
        flyer_id = new_id()
        try:
            client.collection("flyers").document(flyer_id).create(document)
        except AlreadyExists:
            continue
        return flyer_id
    raise RuntimeError(f"no free flyer id after {attempts} tries")


def timetable(source: str, folder: Path) -> Path:
    """`source` as a local zip: a path as given, a URL downloaded into `folder`."""
    if not source.startswith(("https://", "http://")):
        return Path(source)
    target = folder / "gtfs.zip"
    request = urllib.request.Request(
        source, headers={"User-Agent": "Ronda-hackathon/0.1 (github.com/Cirorx/ronda)"}
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        target.write_bytes(response.read())
    return target


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--lat", type=float, required=True, help="where it hangs: latitude")
    parser.add_argument("--lng", type=float, required=True, help="where it hangs: longitude")
    parser.add_argument("--label", required=True, help="the spot, for the admin only")
    parser.add_argument("--pretext", default="mate", choices=list(HEADLINES))
    parser.add_argument("--slot", help="the day and band it announces, as in sat-afternoon")
    parser.add_argument("--barrio", choices=list(DEMO_BARRIOS), help="default: the nearest")
    parser.add_argument("--stop", help="a GTFS stop_id; default: the nearest stop")
    parser.add_argument("--gtfs", default=last_bus.DNT_GTFS, help="the timetable: URL or zip")
    parser.add_argument("--base-url", help="default: https://{project}.firebaseapp.com")
    parser.add_argument("--out", type=Path, help="the PDF; default: flyer-{id}.pdf here")
    parser.add_argument("--project", help="write to this project (the real one without hosts)")
    args = parser.parse_args(argv)

    if args.slot and not SLOT.fullmatch(args.slot):
        parser.error(f"--slot must look like sat-afternoon, not {args.slot}")
    emulator = os.environ.get(seed.FIRESTORE_HOST)
    if not args.project and not emulator:
        print(
            f"{seed.FIRESTORE_HOST} is not set: without --project this script only writes to "
            "the emulator."
        )
        return 1
    project = args.project or seed.project_id()
    client = seed.firestore_client(project) if emulator else _real_client(project)

    spot = (args.lat, args.lng)
    barrio = args.barrio or barrio_at(spot)
    with tempfile.TemporaryDirectory() as folder:
        archive = timetable(args.gtfs, Path(folder))
        stops = last_bus.read_stops(archive)
        if args.stop and args.stop not in stops:
            print(f"No stop {args.stop} in the timetable.")
            return 1
        candidates = last_bus.nearest_stops(stops, spot)
        stop = stops[args.stop] if args.stop else candidates[0][0]
        feed = last_bus.read_feed(archive, {c.id for c, _ in candidates} | {stop.id}, stops)
    today = datetime.now(URUGUAY).date()
    print("Nearest stops and their last buses (choose another with --stop):")
    for candidate, metres in candidates:
        print(f"  {candidate.id}  {metres:4.0f} m  {candidate.name}")
        for day_type, bus in last_bus.last_buses(feed, candidate.id, today).items():
            print(f"      {day_type:8} {_describe(bus)}")

    document = flyer_document(
        label=args.label,
        pretext=args.pretext,
        slot=args.slot,
        barrio=barrio,
        near=near_barrios(spot, barrio),
        stop=stop,
        buses=last_bus.last_buses(feed, stop.id, today),
        now=datetime.now(UTC),
    )
    flyer_id = create(client, document)
    url = f"{(args.base_url or f'https://{project}.firebaseapp.com').rstrip('/')}/f/{flyer_id}"
    out = args.out or Path(f"flyer-{flyer_id}.pdf")
    flyer_pdf.write_pdf(
        out, flyer_text(args.pretext, args.slot, barrio), url, f"Volante de Ronda {flyer_id}"
    )
    where = f"the emulator at {emulator}" if emulator else "the real project"
    print(
        f"Flyer {flyer_id} in {project} ({where}): {BARRIO_NAMES[barrio]}, stop {stop.id} "
        f"({stop.name}), showing {', '.join(document['nearBarrios'])}.\n{url}\n{out}"
    )
    return 0


def _real_client(project: str):
    from google.cloud import firestore

    return firestore.Client(project=project)


def _describe(bus: dict | None) -> str:
    if bus is None:
        return "no bus"
    reckoned = f", from {bus['published']['time']} at {bus['published']['stop']}"
    return f"{bus['time']} line {bus['route']}" + (reckoned if bus["estimated"] else " (timed)")


if __name__ == "__main__":
    sys.exit(main())
