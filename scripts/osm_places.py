# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = [
#     "google-cloud-firestore>=2.21,<3",
# ]
# ///
"""Fill the OpenStreetMap cache Algo chico esta semana reads: free public places near the demo
barrios, as `osm_places/{id}` (docs/ARCHITECTURE.md § Data model).

One Overpass query for Ciudad de la Costa, run from here and never from the phone, with a
User-Agent and no parallel queries (Overpass's rules); it takes about 40 s. Plazas and parks
(`leisure=park`), ramblas (a named way or a `leisure=promenade` starting with "Rambla"),
libraries and marketplaces (`amenity=library|marketplace`), each with its name, the point of
its centre and its `opening_hours` when it has them. A place with no name is left out. The
data is OpenStreetMap's, © its contributors, under the ODbL: the README credits it, and the
cache keeps `source` and `fetchedAt` on every document.

    uv run --python 3.13 scripts/osm_places.py --dry-run
    FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 uv run --python 3.13 scripts/osm_places.py
    uv run --python 3.13 scripts/osm_places.py --project ronda-uy  # with ADC

Documents are `osm_places/{node|way|relation}-{id}`, written with `merge=False`, so running it
again refreshes them; places that have since left OpenStreetMap are deleted, and the invented
`demo-*` ones are never touched. Nothing is committed: the data stays in Firestore.
"""

import argparse
import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import UTC, datetime

OVERPASS = "https://overpass-api.de/api/interpreter"
USER_AGENT = "Ronda-hackathon/0.1 (github.com/Cirorx/ronda)"
BOX = "(-34.87,-56.03,-34.76,-55.83)"
"""South, west, north, east: Ciudad de la Costa, as smoke test 7 asks."""
QUERY = (
    f'[out:json][timeout:60];(nwr["leisure"~"^(park|promenade)$"]["name"]{BOX};'
    f'nwr["highway"~"^(pedestrian|footway|path)$"]["name"~"^Rambla"]{BOX};'
    f'nwr["amenity"~"^(library|marketplace)$"]["name"]{BOX};);out center 400;'
)
SOURCE = "OpenStreetMap contributors, ODbL"
BATCH_LIMIT = 450
"""Firestore allows 500 writes in a batch."""

ARTICLES = (
    ("Plaza", "la "),
    ("Biblioteca", "la "),
    ("Rambla", "la "),
    ("Feria", "la "),
    ("Parque", "el "),
    ("Mercado", "el "),
    ("Paseo", "el "),
)
BY_KIND = {
    "park": "el parque ",
    "promenade": "la ",
    "library": "la biblioteca ",
    "marketplace": "la feria ",
}


def kind_of(tags: dict) -> str | None:
    """Which of the four kinds the place is, or `None` when it is none of them."""
    if tags.get("amenity") == "library":
        return "library"
    if tags.get("amenity") == "marketplace":
        return "marketplace"
    if tags.get("name", "").startswith("Rambla") or tags.get("leisure") == "promenade":
        return "promenade"
    if tags.get("leisure") == "park":
        return "park"
    return None


def with_article(name: str, kind: str) -> str:
    """The name as a sentence needs it: "Plaza Seregni" is "la Plaza Seregni"; "Los Aromos", a
    park, is "el parque Los Aromos"."""
    for start, article in ARTICLES:
        if name.startswith(start):
            return f"{article}{name}"
    return f"{BY_KIND[kind]}{name}"


def to_documents(elements: list[dict], fetched_at: datetime) -> dict[str, dict]:
    """`osm_places/{id}` documents from Overpass's `elements`: the named places of the four
    kinds that have a point."""
    documents = {}
    for element in elements:
        tags = element.get("tags") or {}
        point = element if "lat" in element else element.get("center") or {}
        kind = kind_of(tags)
        if kind is None or not tags.get("name") or "lat" not in point:
            continue
        fields = {
            "name": with_article(tags["name"].strip(), kind),
            "kind": kind,
            "lat": round(point["lat"], 5),
            "lng": round(point["lon"], 5),
            "source": SOURCE,
            "fetchedAt": fetched_at,
        }
        if hours := tags.get("opening_hours"):
            fields["openingHours"] = hours
        documents[f"osm_places/{element['type']}-{element['id']}"] = fields
    return documents


def fetch() -> list[dict]:
    """The elements of the Overpass query, one request."""
    request = urllib.request.Request(
        OVERPASS,
        data=urllib.parse.urlencode({"data": QUERY}).encode(),
        headers={"User-Agent": USER_AGENT},
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        return json.load(response)["elements"]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--project", help="write to this project (Application Default Credentials)")
    parser.add_argument("--dry-run", action="store_true", help="fetch and count; write nothing")
    args = parser.parse_args(argv)

    documents = to_documents(fetch(), datetime.now(UTC))
    by_kind: dict[str, int] = {}
    for fields in documents.values():
        by_kind[fields["kind"]] = by_kind.get(fields["kind"], 0) + 1
    print(f"{len(documents)} places: {by_kind}")
    if args.dry_run:
        return 0

    from google.auth.credentials import AnonymousCredentials
    from google.cloud import firestore

    emulator = os.environ.get("FIRESTORE_EMULATOR_HOST")
    if not emulator and not args.project:
        print("Set FIRESTORE_EMULATOR_HOST, or pass --project for a real project.")
        return 1
    client = (
        firestore.Client(project=args.project or "ronda-uy", credentials=AnonymousCredentials())
        if emulator
        else firestore.Client(project=args.project)
    )
    stale = [
        ref
        for ref in client.collection("osm_places").list_documents()
        if not ref.id.startswith("demo-") and f"osm_places/{ref.id}" not in documents
    ]
    writes = [("set", client.document(path), fields) for path, fields in documents.items()]
    writes += [("delete", ref, None) for ref in stale]
    for start in range(0, len(writes), BATCH_LIMIT):
        batch = client.batch()
        for action, ref, *fields in writes[start : start + BATCH_LIMIT]:
            getattr(batch, action)(ref, *fields)
        batch.commit()
    print(f"Wrote {len(documents)}, deleted {len(stale)} that left OpenStreetMap.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
