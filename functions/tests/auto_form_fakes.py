"""Two invented neighbours in Cordón who both want mate on Thursday afternoons, and three
invented public places near them, for auto_form.py and auto_setup.py. Monday 2026-11-02 is
the day; the first meeting is Thursday 2026-11-05."""

from tests.organiser_fakes import at

SEAT = "cordon_mate_thu-afternoon"
PEOPLE = {"demo-af-1": ("Ana", "60-69"), "demo-af-2": ("Beto", "30-39")}
PLAZA = "plaza-inventada"
BIBLIOTECA = "biblioteca-inventada"
RAMBLA = "rambla-inventada"
MON_10 = at(2, 10)
MON_23 = at(2, 23)
TUE_09 = at(3, 9)


def sign_ups(*, places: bool = True) -> dict[str, dict]:
    documents: dict[str, dict] = {}
    for uid, (name, band) in PEOPLE.items():
        documents[f"users/{uid}"] = {
            "firstName": name,
            "ageBand": band,
            "barrio": "cordon",
            "slots": ["thu-afternoon"],
            "pretexts": ["mate"],
            "brings": ["termo"],
        }
        documents[f"users/{uid}/private/eligible"] = {"seatIds": [SEAT]}
        documents[f"users/{uid}/tokens/tok-{uid}"] = {"platform": "android"}
    if places:
        documents[f"osm_places/{BIBLIOTECA}"] = {
            # The nearest, and closed in the afternoon.
            "name": "la Biblioteca Inventada",
            "kind": "library",
            "lat": -34.9036,
            "lng": -56.1780,
            "openingHours": "Mo-Fr 09:00-13:00",
        }
        documents[f"osm_places/{PLAZA}"] = {
            "name": "la Plaza Inventada",
            "kind": "park",
            "lat": -34.9042,
            "lng": -56.1786,
        }
        documents[f"osm_places/{RAMBLA}"] = {
            "name": "la Rambla Inventada",
            "kind": "promenade",
            "lat": -34.9070,
            "lng": -56.1810,
        }
    return documents
