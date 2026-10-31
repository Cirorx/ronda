"""The plan-schema filter (#56), written before the code it tests: what the model's draft may
become, and what drops it. Every sentence here is invented."""

import pytest

import small_plans as sp


def draft(**fields) -> sp.Draft:
    base = {
        "activity": "Caminar 30 minutos por la rambla",
        "day": "tue",
        "time": "19:00",
        "place": "desde la parada 23",
        "kind": "walk",
        "outdoor": True,
        "flag": "none",
    }
    return sp.Draft(**(base | fields))


class TestWhatPasses:
    def test_a_walk_with_a_day_a_time_and_a_place_passes_as_it_is(self):
        plan = sp.filter_plan(draft(), "Quiero caminar el martes a las siete")

        assert plan == sp.Shaped(
            activity="Caminar 30 minutos por la rambla",
            day="tue",
            time="19:00",
            place="desde la parada 23",
            kind="walk",
            outdoor=True,
        )

    def test_unknown_day_and_time_read_as_not_said(self):
        plan = sp.filter_plan(draft(day="unknown", time="unknown"), "caminar por la rambla")

        assert (plan.day, plan.time) == (None, None)

    def test_a_time_outside_the_day_reads_as_not_said(self):
        assert sp.filter_plan(draft(time="03:00"), "caminar").time is None
        assert sp.filter_plan(draft(time="22:30"), "caminar").time is None
        assert sp.filter_plan(draft(time="7pm"), "caminar").time is None

    def test_the_first_letter_is_a_capital_and_markdown_is_gone(self):
        plan = sp.filter_plan(draft(activity="**ir** a la feria"), "ir a la feria")

        assert plan.activity == "Ir a la feria"

    def test_a_long_activity_is_cut_at_eighty_characters(self):
        plan = sp.filter_plan(draft(activity="Caminar " + "mucho " * 40), "caminar")

        assert len(plan.activity) <= 80

    def test_no_place_is_an_empty_place_that_stays_none(self):
        assert sp.filter_plan(draft(place="  "), "caminar").place is None

    def test_a_calling_plan_that_names_nobody_passes(self):
        plan = sp.filter_plan(
            draft(activity="Llamar a alguien con quien hace tiempo no hablo", kind="call"),
            "quiero llamar a alguien con quien hace tiempo no hablo",
        )

        assert plan.kind == "call"


class TestWhatDropsThePlan:
    @pytest.mark.parametrize(
        "words",
        [
            "quiero hacer ejercicio para bajar la presión",
            "caminar por el colesterol",
            "ir al médico el martes",
            "ir a terapia el jueves",
            "caminar para mejorar mi salud",
            "I want to walk for my health",
        ],
    )
    def test_health_and_medical_goals_in_what_the_person_said(self, words):
        assert sp.filter_plan(draft(), words) == sp.Rejected("health")

    @pytest.mark.parametrize(
        "words",
        ["caminar para bajar de peso", "empezar una dieta el lunes", "contar las calorías"],
    )
    def test_diets_and_weight(self, words):
        assert sp.filter_plan(draft(), words) == sp.Rejected("diet")

    @pytest.mark.parametrize(
        "words",
        [
            "ir a la feria a comprar verduras",
            "caminar hasta el banco a pagar la cuenta",
            "ahorrar cien pesos esta semana",
            "I want to buy shoes",
        ],
    )
    def test_money(self, words):
        assert sp.filter_plan(draft(), words) == sp.Rejected("money")

    @pytest.mark.parametrize(
        "words",
        [
            "caminar con mi hija el martes",
            "ir con mis nietos a la plaza",
            "llamar a Marta",
            "salir con Ana a caminar",
            "visit my neighbour on Tuesday",
        ],
    )
    def test_anything_about_other_people(self, words):
        assert sp.filter_plan(draft(), words) == sp.Rejected("people")

    def test_the_models_own_flag_drops_the_plan_even_when_the_words_look_fine(self):
        for flag in ("health", "diet", "money", "people"):
            assert sp.filter_plan(draft(flag=flag), "caminar") == sp.Rejected(flag)

    def test_health_in_the_activity_the_model_wrote_drops_it_too(self):
        plan = sp.filter_plan(draft(activity="Caminar para la salud"), "caminar por la rambla")

        assert plan == sp.Rejected("health")

    def test_money_the_model_put_in_the_place_drops_it(self):
        assert sp.filter_plan(draft(place="en el cajero, 200 pesos"), "caminar") == sp.Rejected(
            "money"
        )

    @pytest.mark.parametrize(
        "fields",
        [
            {"activity": "Caminar 🧉"},
            {"activity": "Puedes caminar por la rambla"},
            {"place": "en lo de Marta"},
            {"place": "Av. Central 1234"},
        ],
    )
    def test_emoji_tu_forms_and_homes_in_what_the_model_wrote_are_unclear(self, fields):
        assert sp.filter_plan(draft(**fields), "caminar") == sp.Rejected("unclear")

    def test_an_empty_activity_is_unclear(self):
        assert sp.filter_plan(draft(activity="   "), "algo") == sp.Rejected("unclear")

    def test_a_walk_is_not_a_health_goal_by_itself(self):
        assert isinstance(sp.filter_plan(draft(), "caminar un rato por la rambla"), sp.Shaped)

    @pytest.mark.parametrize(
        "words",
        [
            "caminar por la costa",
            "pasear por la Costanera hasta Paysandú",
            "sentarme en un banco de la plaza",
            "mi primera caminata por la rambla",
            "mi primer paseo por el barrio",
            "me animo a salir a la feria",
        ],
    )
    def test_words_that_only_look_like_a_topic_pass(self, words):
        assert isinstance(sp.filter_plan(draft(), words), sp.Shaped)

    @pytest.mark.parametrize(
        ("words", "reason"),
        [
            ("quiero levantar el ánimo", "health"),
            ("ir a pagar la luz", "money"),
            ("I want to spend the day out", "money"),
            ("salir con mi primo", "people"),
        ],
    )
    def test_the_topics_they_look_like_still_drop_the_plan(self, words, reason):
        assert sp.filter_plan(draft(), words) == sp.Rejected(reason)

    def test_a_place_name_with_a_capital_after_a_is_not_a_person(self):
        words = "caminar de la plaza a la rambla de Solymar"

        assert isinstance(sp.filter_plan(draft(), words), sp.Shaped)
