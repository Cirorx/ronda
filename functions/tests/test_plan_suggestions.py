"""The three suggestions: the candidates code builds, and the model's (or the rules') pick."""

import json
import logging
from datetime import date, time

import pytest

import free_places as fp
import plan_suggestions as ps
from organiser.model import ModelUnavailable, Turn
from tests.organiser_fakes import ScriptedModel
from tests.small_plan_fakes import MONDAY, NOW, FakeForecast, week

SATURDAY = date(2026, 11, 7)
USER = {"barrio": "solymar-norte", "pretexts": ["mate", "caminata", 5]}


def place(place_id, name, kind, hours=None, blocks=3):
    return fp.Place(place_id, name, kind, blocks, hours)


PLAZA = place("plaza", "la Plaza de los Aromos", fp.PARK)
RAMBLA = place("rambla", "la Rambla de Solymar", fp.PROMENADE, blocks=5)
BIBLIO = place("biblio", "la Biblioteca de Solymar", fp.LIBRARY, "Mo-Fr 10:00-18:00")
FERIA = place("feria", "la Feria de Solymar", fp.MARKETPLACE, "Sa 08:00-14:00")
PLACES = [PLAZA, RAMBLA, BIBLIO, FERIA]


def found(places=PLACES, table=None):
    return ps.candidates(places, now=NOW, week=week() if table is None else table)


def kinds(candidates):
    return [(c.id, c.kind, c.place.id if c.place else None) for c in candidates]


class TestCandidates:
    def test_each_kind_gets_its_nearest_places_and_the_two_without_a_place(self):
        assert kinds(found()) == [
            ("walk-1", "walk", "plaza"),
            ("walk-2", "walk", "rambla"),
            ("feria-1", "feria", "feria"),
            ("library-1", "library", "biblio"),
            ("call-1", "call", None),
            ("noPhone-1", "noPhone", None),
        ]

    def test_at_most_two_places_a_kind(self):
        three = [place(f"p{n}", f"el Parque {n}", fp.PARK) for n in range(3)]

        assert [c.id for c in found(three) if c.kind == "walk"] == ["walk-1", "walk-2"]

    def test_with_no_place_near_a_walk_is_still_on_offer(self):
        assert kinds(found([])) == [
            ("walk-1", "walk", None),
            ("call-1", "call", None),
            ("noPhone-1", "noPhone", None),
        ]

    def test_the_feria_is_on_the_day_its_hours_say_and_never_without_hours(self):
        no_hours = place("sin-horario", "la Feria sin horario", fp.MARKETPLACE)

        ferias = [c for c in found([FERIA, no_hours]) if c.kind == "feria"]

        assert [(c.place.id, c.slot.on, c.slot.at) for c in ferias] == [
            ("feria", SATURDAY, time(10))
        ]

    def test_the_library_is_only_offered_on_the_days_it_is_open(self):
        [library] = [c for c in found() if c.kind == "library"]

        assert library.slot.on == MONDAY  # Mo-Fr 10:00-18:00, offered at 16:00
        weekend = place("biblio", "la Biblioteca", fp.LIBRARY, "Sa,Su 10:00-18:00")
        [library] = [c for c in found([weekend]) if c.kind == "library"]
        assert library.slot.on == SATURDAY

    def test_a_place_closed_all_week_is_not_offered(self):
        closed = place("cerrada", "la Biblioteca cerrada", fp.LIBRARY, "Nov-Mar Mo 09:00-18:00")

        assert [c for c in found([closed]) if c.kind == "library"] == []

    def test_outdoor_kinds_get_a_dry_day_and_indoor_ones_do_not_care(self):
        candidates = found(table=week(wet=(0, 1)))

        walk = next(c for c in candidates if c.kind == "walk")
        library = next(c for c in candidates if c.kind == "library")
        assert (walk.slot.on, walk.slot.dry, walk.outdoor) == (date(2026, 11, 4), True, True)
        assert (library.slot.on, library.slot.dry, library.outdoor) == (MONDAY, None, False)

    def test_a_kind_with_no_day_left_is_left_out(self, monkeypatch):
        monkeypatch.setattr(ps.small_plans, "candidate_days", lambda now, at: [])

        assert found() == []

    def test_the_hours_read_the_days_own_sunset(self):
        night = place("noche", "la Plaza de noche", fp.PARK, "sunrise-sunset")

        assert found([night])[0].place.id == "noche"  # 18:00 is before sunset 19:50
        assert found([night], {})[0].place.id == "noche"  # no forecast: sunset reads 19:00


class TestByRules:
    def test_one_of_each_kind_in_order(self):
        assert [c.id for c in ps.by_rules(found())] == ["walk-1", "feria-1", "library-1"]

    def test_fills_up_with_more_of_a_kind_when_kinds_run_out(self):
        assert [c.id for c in ps.by_rules(found([PLAZA, RAMBLA]))] == [
            "walk-1",
            "call-1",
            "noPhone-1",
        ]
        only_walks = [c for c in found() if c.kind == "walk"]
        assert [c.id for c in ps.by_rules(only_walks)] == ["walk-1", "walk-2"]


def answering(content):
    return ScriptedModel([Turn(content=content, model="scripted")])


class TestByModel:
    def pick(self, content, pretexts=("mate",)):
        return ps.by_model(found(), list(pretexts), week(), answering(content))

    def test_takes_the_models_three_in_its_order(self):
        picked = self.pick('{"ids": ["call-1", "walk-2", "library-1"]}')

        assert [c.id for c in picked] == ["call-1", "walk-2", "library-1"]

    def test_reads_json_inside_a_markdown_fence(self):
        picked = self.pick('```json\n{"ids": ["call-1", "walk-1", "noPhone-1"]}\n```')

        assert [c.id for c in picked] == ["call-1", "walk-1", "noPhone-1"]

    def test_leaves_out_ids_that_do_not_exist_and_repeats_then_fills_by_the_rules(self):
        picked = self.pick('{"ids": ["call-1", "casino-9", "call-1", 7]}')

        assert [c.id for c in picked] == ["call-1", "walk-1", "feria-1"]

    def test_never_more_than_three(self):
        picked = self.pick('{"ids": ["walk-1", "walk-2", "feria-1", "library-1", "call-1"]}')

        assert [c.id for c in picked] == ["walk-1", "walk-2", "feria-1"]

    @pytest.mark.parametrize(
        "content",
        ["", "no sé", '{"ids": []}', '{"ids": "walk-1"}', '{"ids": ["nope"]}', "{broken}", "[1]"],
    )
    def test_an_answer_with_nothing_usable_is_the_model_failing(self, content):
        with pytest.raises(ModelUnavailable):
            self.pick(content)

    def test_asks_with_what_the_member_likes_and_each_ideas_day_and_rain_but_no_tools(self):
        model = answering('{"ids": ["walk-1"]}')

        rainy = week(wet=(0,))
        ps.by_model(found(table=rainy), ["mate", "caminata", "not-a-pretext"], rainy, model)

        [(messages, tools)] = model.requests
        assert tools == []
        request = json.loads(messages[1]["content"])
        assert request["leGusta"] == ["mate en la rambla", "caminata"]
        walk = next(i for i in request["ideas"] if i["id"] == "walk-1")
        assert walk == {
            "id": "walk-1",
            "kind": "walk",
            "place": "la Plaza de los Aromos",
            "day": "tue",
            "rainProbability": 5,
        }
        assert next(i for i in request["ideas"] if i["id"] == "call-1")["place"] is None
        assert "uid" not in messages[1]["content"]


class TestSuggest:
    def suggest(self, model, *, user=USER, places=PLACES, forecast=None):
        return ps.suggest(
            user=user,
            places=places,
            now=NOW,
            weather=forecast or FakeForecast(),
            model=model,
        )

    def test_the_model_picks_and_each_suggestion_is_a_kind_a_place_a_day_and_a_time(self):
        answer = self.suggest(answering('{"ids": ["feria-1", "call-1", "walk-1"]}'))

        assert answer["pickedBy"] == "model"
        assert answer["suggestions"][0] == {
            "id": "feria-1",
            "kind": "feria",
            "place": "la Feria de Solymar",
            "date": "2026-11-07",
            "time": "10:00",
            "outdoor": True,
            "dry": True,
        }
        assert answer["suggestions"][1] == {
            "id": "call-1",
            "kind": "call",
            "place": None,
            "date": "2026-11-02",
            "time": "18:00",
            "outdoor": False,
            "dry": None,
        }

    def test_the_rules_pick_with_no_model(self):
        answer = self.suggest(None)

        assert answer["pickedBy"] == "rules"
        assert [s["id"] for s in answer["suggestions"]] == ["walk-1", "feria-1", "library-1"]

    def test_the_rules_pick_when_the_model_fails(self, caplog):
        model = ScriptedModel([ModelUnavailable("down")])

        with caplog.at_level(logging.WARNING):
            answer = self.suggest(model)

        assert answer["pickedBy"] == "rules"
        assert "the rules pick" in caplog.text

    def test_a_member_with_no_profile_still_gets_three(self):
        answer = self.suggest(None, user=None, places=[])

        assert [s["kind"] for s in answer["suggestions"]] == ["walk", "call", "noPhone"]
        assert all(s["dry"] is None for s in answer["suggestions"] if s["outdoor"])

    def test_open_meteo_down_still_gives_three_with_no_word_on_the_rain(self):
        answer = self.suggest(None, forecast=FakeForecast(fail=True))

        assert len(answer["suggestions"]) == 3
