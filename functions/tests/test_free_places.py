"""The free places near a barrio, from the OSM cache stand-in."""

import pytest

import free_places as fp
from tests.fake_firestore import FakeFirestore

SOLYMAR_NORTE = (-34.8255, -55.9420)


def place(name="la Plaza de los Aromos", kind="park", at=(0.0, 0.0), **fields):
    lat, lng = SOLYMAR_NORTE[0] + at[0], SOLYMAR_NORTE[1] + at[1]
    return {"name": name, "kind": kind, "lat": lat, "lng": lng, **fields}


def nearby(documents, barrio="solymar-norte"):
    return fp.nearby(FakeFirestore({f"osm_places/{k}": v for k, v in documents.items()}), barrio)


class TestNearby:
    def test_lists_the_places_within_ten_blocks_nearest_first(self):
        found = nearby(
            {
                "far": place("el Parque Lejano", at=(0.02, 0.0)),  # ~2.2 km
                "b": place("la Biblioteca", "library", at=(0.005, 0.0)),  # ~550 m
                "a": place("la Plaza", at=(0.001, 0.0)),
            }
        )

        assert [(p.id, p.name, p.kind) for p in found] == [
            ("a", "la Plaza", "park"),
            ("b", "la Biblioteca", "library"),
        ]
        assert found[0].blocks <= found[1].blocks <= fp.MAX_BLOCKS

    def test_carries_the_opening_hours_when_there_are_some(self):
        found = nearby({"a": place(openingHours="Mo-Fr 09:00-18:00"), "b": place(openingHours=42)})

        assert {p.id: p.hours for p in found} == {"a": "Mo-Fr 09:00-18:00", "b": None}

    @pytest.mark.parametrize("barrio", [None, 5, "not-a-barrio"])
    def test_a_barrio_the_app_does_not_know_has_no_places(self, barrio):
        assert nearby({"a": place()}, barrio) == []

    @pytest.mark.parametrize(
        "fields",
        [
            {"name": 5},
            {"kind": "casino"},
            {"lat": "x"},
            {"lng": None},
            {"name": "el Parque, cobran la entrada, $50"},
            {"name": "la Plaza de Av. Central 1234"},
        ],
    )
    def test_leaves_out_a_place_that_cannot_be_offered(self, fields):
        assert nearby({"a": place() | fields}) == []

    def test_an_invented_place_counts_only_where_invented_people_do(self, monkeypatch):
        documents = {"demo-plaza": place()}

        assert nearby(documents) != []  # the tests run as a demo project
        monkeypatch.setenv("GCLOUD_PROJECT", "ronda-uy")
        assert nearby(documents) == []
