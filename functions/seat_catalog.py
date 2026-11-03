"""Publishes the seat catalogue (ronda_solver.seats) so every phone can match its needs against
it: `seat_facts/{barrio}_{pretext}` for every barrio and pretext, and `config/seat_catalog`
with the catalogue's version and when it went out.

The hourly dispatcher runs it, so a deploy that changes the catalogue reaches phones within the
hour, with no script or credentials on anyone's computer. While the version in `config/seat_catalog`
matches it writes nothing and costs one read. A phone that saw another version works out its
eligible seats again on its next launch (lib/app/cubit/seat_refresh_cubit.dart).

Per-slot `seat_facts` documents (a host's place for one slot, or an older seed's) are left as they
are: the phone lets them replace their expanded twin.
"""

from datetime import datetime

from ronda_solver.seats import catalogue, version

CONFIG = "config/seat_catalog"
COLLECTION = "seat_facts"
BATCH_SIZE = 400
"""Writes per commit, under Firestore's 500."""


def run_seat_catalog(db, now: datetime, *, force: bool = False) -> dict:
    """Writes the catalogue when its version differs from the published one, or with `force`."""
    documents = catalogue()
    current = version(documents)
    published = db.document(CONFIG).get()
    if not force and published.exists and (published.to_dict() or {}).get("version") == current:
        return {"version": current, "published": 0}
    items = sorted(documents.items())
    for start in range(0, len(items), BATCH_SIZE):
        batch = db.batch()
        for seat_id, fields in items[start : start + BATCH_SIZE]:
            batch.set(db.document(f"{COLLECTION}/{seat_id}"), fields)
        batch.commit()
    db.document(CONFIG).set({"version": current, "seats": len(items), "updatedAt": now})
    return {"version": current, "published": len(items)}
