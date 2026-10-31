from datetime import UTC, datetime

import pytest

import osm_places

FETCHED = datetime(2026, 11, 1, 12, 0, tzinfo=UTC)


def way(osm_id, tags, center=(-34.83, -55.94)):
    return {
        "type": "way",
        "id": osm_id,
        "center": {"lat": center[0], "lon": center[1]},
        "tags": tags,
    }


class TestKindOf:
    @pytest.mark.parametrize(
        ("tags", "kind"),
        [
            ({"leisure": "park"}, "park"),
            ({"amenity": "library"}, "library"),
            ({"amenity": "marketplace"}, "marketplace"),
            ({"leisure": "promenade", "name": "Paseo"}, "promenade"),
            ({"highway": "footway", "name": "Rambla de Lagomar"}, "promenade"),
            ({"highway": "footway", "name": "Calle 5"}, None),
            ({}, None),
        ],
    )
    def test_the_four_kinds(self, tags, kind):
        assert osm_places.kind_of(tags) == kind


class TestWithArticle:
    @pytest.mark.parametrize(
        ("name", "kind", "named"),
        [
            ("Plaza Seregni", "park", "la Plaza Seregni"),
            ("Parque Roosevelt", "park", "el Parque Roosevelt"),
            ("Los Aromos", "park", "el parque Los Aromos"),
            ("Anaquel", "library", "la biblioteca Anaquel"),
            ("Tristán Narvaja", "marketplace", "la feria Tristán Narvaja"),
            ("Costanera", "promenade", "la Costanera"),
        ],
    )
    def test_gives_the_name_its_article(self, name, kind, named):
        assert osm_places.with_article(name, kind) == named


class TestToDocuments:
    def test_keeps_the_named_places_of_the_four_kinds_with_a_point(self):
        documents = osm_places.to_documents(
            [
                way(1, {"leisure": "park", "name": "Plaza Seregni"}),
                {
                    "type": "node",
                    "id": 2,
                    "lat": -34.8,
                    "lon": -55.9,
                    "tags": {
                        "amenity": "library",
                        "name": "Biblioteca Barrial",
                        "opening_hours": "Mo-Fr 10:00-18:00",
                    },
                },
                way(3, {"leisure": "park"}),  # no name
                way(4, {"shop": "bakery", "name": "Panadería"}),  # not a kind
                {"type": "way", "id": 5, "tags": {"leisure": "park", "name": "Sin punto"}},
            ],
            FETCHED,
        )

        assert documents == {
            "osm_places/way-1": {
                "name": "la Plaza Seregni",
                "kind": "park",
                "lat": -34.83,
                "lng": -55.94,
                "source": osm_places.SOURCE,
                "fetchedAt": FETCHED,
            },
            "osm_places/node-2": {
                "name": "la Biblioteca Barrial",
                "kind": "library",
                "lat": -34.8,
                "lng": -55.9,
                "source": osm_places.SOURCE,
                "fetchedAt": FETCHED,
                "openingHours": "Mo-Fr 10:00-18:00",
            },
        }

    def test_an_element_with_no_tags_is_skipped(self):
        assert (
            osm_places.to_documents([{"type": "node", "id": 1, "lat": 0, "lon": 0}], FETCHED) == {}
        )


class TestMain:
    @pytest.fixture(autouse=True)
    def fetching(self, monkeypatch):
        monkeypatch.setattr(
            osm_places, "fetch", lambda: [way(1, {"leisure": "park", "name": "Plaza Seregni"})]
        )
        monkeypatch.delenv("FIRESTORE_EMULATOR_HOST", raising=False)

    def test_a_dry_run_counts_and_writes_nothing(self, capsys):
        assert osm_places.main(["--dry-run"]) == 0
        assert "1 places: {'park': 1}" in capsys.readouterr().out

    def test_it_needs_the_emulator_or_a_project_to_write_to(self, capsys):
        assert osm_places.main([]) == 1
        assert "FIRESTORE_EMULATOR_HOST" in capsys.readouterr().out
