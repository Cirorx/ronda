"""Casa and trabajo: a neighbour may be seated from either, and a barrio's neighbours widen it."""

import pytest

from ronda_solver import solve
from ronda_solver.anchors import Anchor, anchors_of, nearest_blocks, within_reach
from tests.builders import BARRIOS, person, problem
from tests.test_solve import five_regulars, ronda_of, solve_checked

TWELVE_BLOCKS_WEST = {"lat": -34.8330, "lng": -55.9511}
"""Invented: ~1,200 m west of Solymar Sur's centroid, beyond its 10-block walk but within 15."""


def test_a_neighbour_who_works_in_a_barrio_is_seated_there_from_trabajo():
    works_in_sur = {**person("demo-w", barrio="el-pinar-sur"), "workBarrio": "solymar-sur"}

    result = solve_checked(problem([*five_regulars(), works_in_sur]))

    assert ronda_of(result, "demo-w") == "solymar-sur_mate_sat-afternoon"
    walks = {m["uid"]: m["distanceBlocks"] for m in result["proposals"][0]["members"]}
    assert walks["demo-w"] == 0


def test_the_proposal_names_casa_never_trabajo():
    works_in_sur = {**person("demo-w", barrio="el-pinar-sur"), "workBarrio": "solymar-sur"}

    result = solve(problem([*five_regulars(), works_in_sur]))

    member = next(m for m in result["proposals"][0]["members"] if m["uid"] == "demo-w")
    assert member["barrio"] == "el-pinar-sur"


def test_a_neighbour_is_seated_from_casa_when_trabajo_is_far():
    lives_in_sur = {**person("demo-c"), "workBarrio": "el-pinar-sur"}

    result = solve_checked(problem([*five_regulars(), lives_in_sur]))

    assert ronda_of(result, "demo-c") == "solymar-sur_mate_sat-afternoon"


def test_twelve_blocks_away_is_too_far_without_the_neighbours():
    barrios = {**BARRIOS, "oeste": TWELVE_BLOCKS_WEST}
    west = person("demo-o", barrio="oeste")

    result = solve_checked(problem([*five_regulars(), west], barrios=barrios))

    assert result["unseated"] == ["demo-o"]


def test_with_the_neighbours_twelve_blocks_away_is_close_enough():
    barrios = {**BARRIOS, "oeste": TWELVE_BLOCKS_WEST}
    west = {**person("demo-o", barrio="oeste"), "barrioNeighbours": True}

    result = solve_checked(problem([*five_regulars(), west], barrios=barrios))

    assert ronda_of(result, "demo-o") == "solymar-sur_mate_sat-afternoon"


def test_trabajo_with_its_neighbours_reaches_as_far_as_casa_would():
    barrios = {**BARRIOS, "oeste": TWELVE_BLOCKS_WEST}
    commuter = {
        **person("demo-o", barrio="el-pinar-sur"),
        "workBarrio": "oeste",
        "workBarrioNeighbours": True,
    }

    result = solve_checked(problem([*five_regulars(), commuter], barrios=barrios))

    assert ronda_of(result, "demo-o") == "solymar-sur_mate_sat-afternoon"


def test_a_trabajo_without_a_centroid_is_refused():
    lost = {**person("demo-0"), "workBarrio": "atlantida"}

    with pytest.raises(ValueError, match="'atlantida', not in barrios"):
        solve(problem([lost]))


def test_an_old_profile_reads_as_casa_without_its_neighbours():
    assert anchors_of({"barrio": "solymar-sur"}) == (Anchor("solymar-sur"),)


def test_trabajo_comes_after_casa_and_the_same_barrio_twice_counts_once():
    profile = {"barrio": "a", "barrioNeighbours": True, "workBarrio": "b"}

    assert anchors_of(profile) == (Anchor("a", neighbours=True), Anchor("b"))
    assert anchors_of({"barrio": "a", "workBarrio": "a"}) == (Anchor("a"),)


def test_an_anchor_in_an_unknown_barrio_or_not_a_string_is_left_out():
    profile = {"barrio": "a", "workBarrio": "nowhere", "workBarrioNeighbours": True}

    assert anchors_of(profile, known={"a"}) == (Anchor("a"),)
    assert anchors_of({"barrio": 3, "workBarrio": "a"}) == (Anchor("a"),)
    assert anchors_of({"barrio": "nowhere"}, known={"a"}) == ()


def test_only_true_switches_the_neighbours_on():
    assert anchors_of({"barrio": "a", "barrioNeighbours": "yes"}) == (Anchor("a"),)


def test_the_nearest_anchor_gives_the_walk_and_none_without_anchors():
    walks = {("a", "seat"): 12.0, ("b", "seat"): 3.0}

    assert nearest_blocks((Anchor("a"), Anchor("b")), "seat", lambda x, y: walks[x, y]) == 3.0
    assert nearest_blocks((), "seat", lambda x, y: 0.0) is None
    assert not within_reach((), "seat", lambda x, y: 0.0)


def test_the_neighbours_reach_one_and_a_half_walks_in_montevideo_too():
    assert Anchor("cordon", neighbours=True).reach("palermo") == 22.5
    assert Anchor("cordon").reach("palermo") == 15
