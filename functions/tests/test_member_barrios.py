"""member_barrios.py: casa, trabajo and their neighbours, as every server path reads them."""

import member_barrios


def test_an_old_profile_meets_from_casa_alone():
    assert member_barrios.barrios({"barrio": "cordon"}) == ["cordon"]


def test_trabajo_comes_second_and_only_when_known():
    assert member_barrios.barrios({"barrio": "cordon", "workBarrio": "centro"}) == [
        "cordon",
        "centro",
    ]
    assert member_barrios.barrios({"barrio": "cordon", "workBarrio": "atlantida"}) == ["cordon"]


def test_without_a_known_casa_there_is_nowhere_to_meet_from():
    assert member_barrios.anchors({"barrio": "atlantida", "workBarrio": "centro"}) == ()
    assert member_barrios.anchors({}) == ()


def test_the_walk_is_from_the_nearest_and_none_for_an_unknown_seat():
    commuter = {"barrio": "shangrila", "workBarrio": "palermo"}

    assert round(member_barrios.nearest_blocks(commuter, "barrio-sur")) == 13
    assert member_barrios.nearest_blocks(commuter, "atlantida") is None
    assert member_barrios.nearest_blocks({"barrio": "atlantida"}, "centro") is None


def test_the_neighbours_widen_the_walk_one_and_a_half_times():
    # Aguada's centroid is beyond Barrio Sur's 15-block walk and within 22.5.
    assert not member_barrios.reaches({"barrio": "aguada"}, "barrio-sur")
    assert member_barrios.reaches({"barrio": "aguada", "barrioNeighbours": True}, "barrio-sur")
    assert not member_barrios.reaches({"barrio": "aguada"}, "atlantida")
