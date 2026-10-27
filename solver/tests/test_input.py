"""The input contract: options the owner can tune, and input the solver refuses."""

import pytest

from ronda_solver import solve
from tests.builders import person, problem


def truco_neighbours():
    young = [
        person(f"demo-y{i}", age_band="18-29", barrio="solymar-norte", pretexts=("truco",))
        for i in range(4)
    ]
    old = [person(f"demo-o{i}", age_band="60-69", pretexts=("truco",)) for i in range(4)]
    return [*young, *old]


def test_a_zero_weight_switches_the_truco_rule_off():
    data = problem(truco_neighbours(), options={"weights": {"trucoCrossAge": 0}})

    result = solve(data)

    bands = {r["id"]: sorted({m["ageBand"] for m in r["members"]}) for r in result["proposals"]}
    assert bands == {
        "solymar-norte_truco_sat-afternoon": ["18-29"],
        "solymar-sur_truco_sat-afternoon": ["60-69"],
    }


def test_an_unknown_soft_rule_weight_is_refused():
    with pytest.raises(ValueError, match="unknown soft rule"):
        solve(problem([person("demo-0")], options={"weights": {"trucoPartners": 0}}))


def test_a_uid_that_appears_twice_is_refused():
    with pytest.raises(ValueError, match="appears twice"):
        solve(problem([person("demo-0"), person("demo-0")]))


def test_a_neighbour_in_a_barrio_without_a_centroid_is_refused():
    with pytest.raises(ValueError, match="not in barrios"):
        solve(problem([person("demo-0", barrio="atlantida")]))


def test_an_id_with_an_underscore_is_refused_because_seat_ids_join_ids_with_one():
    with pytest.raises(ValueError, match="'sat_afternoon'"):
        solve(problem([person("demo-0", slots=("sat_afternoon",))]))
