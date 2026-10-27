from ronda_solver import check, score, solve
from tests.builders import BARRIOS, members_of, person, problem

SOLYMAR_SUR_ONLY = {"solymar-sur": BARRIOS["solymar-sur"]}


def solve_checked(data):
    """Solves to optimality, and fails unless the checker finds every hard rule kept and the
    solver's objective matches the soft rules scored from the groups alone."""
    result = solve(data)
    assert check(data, result) == []
    assert result["status"] == "optimal"
    assert result["stats"]["objective"] == score(data, result)["objective"]
    if result["rejectedAlternative"] is not None:
        assert check(data, result["rejectedAlternative"]) == []
    return result


def test_five_neighbours_with_the_same_barrio_pretext_and_slot_form_one_ronda():
    people = [person(f"demo-{i}") for i in range(5)]

    result = solve_checked(problem(people, barrios=SOLYMAR_SUR_ONLY))

    assert members_of(result) == {
        "solymar-sur_mate_sat-afternoon": ["demo-0", "demo-1", "demo-2", "demo-3", "demo-4"]
    }
    assert result["unseated"] == []


def five_regulars(**overrides):
    return [person(f"demo-{i}", **overrides) for i in range(5)]


def test_a_neighbour_is_never_seated_in_a_slot_they_did_not_pick():
    eligible_but_wrong_slot = person(
        "demo-x",
        slots=("sun-morning",),
        eligible=["solymar-sur_mate_sat-afternoon"],
    )

    result = solve_checked(
        problem([*five_regulars(), eligible_but_wrong_slot], barrios=SOLYMAR_SUR_ONLY)
    )

    assert result["unseated"] == ["demo-x"]


def test_a_neighbour_is_never_seated_in_a_pretext_they_did_not_pick():
    eligible_but_wrong_pretext = person(
        "demo-x",
        pretexts=("truco",),
        eligible=["solymar-sur_mate_sat-afternoon"],
    )

    data = problem([*five_regulars(), eligible_but_wrong_pretext], barrios=SOLYMAR_SUR_ONLY)

    result = solve_checked(data)

    assert result["unseated"] == ["demo-x"]


def test_a_neighbour_is_never_seated_in_a_seat_their_phone_filtered_out():
    filtered_out = person("demo-x", eligible=[])

    result = solve_checked(problem([*five_regulars(), filtered_out], barrios=SOLYMAR_SUR_ONLY))

    assert result["unseated"] == ["demo-x"]


def test_a_neighbour_more_than_ten_blocks_away_is_never_seated():
    far = person("demo-far", barrio="el-pinar-sur")

    result = solve_checked(problem([*five_regulars(), far]))

    assert result["unseated"] == ["demo-far"]


def test_a_neighbour_nine_blocks_away_is_seated_with_their_walk_in_blocks():
    # Solymar Norte's centroid is ~910 m from Solymar Sur's (haversine); a block is 100 m.
    nine_blocks = person("demo-near", barrio="solymar-norte")

    result = solve_checked(problem([*five_regulars(), nine_blocks]))

    [ronda] = result["proposals"]
    walks = {m["uid"]: m["distanceBlocks"] for m in ronda["members"]}
    assert ronda["id"] == "solymar-sur_mate_sat-afternoon"
    assert walks["demo-near"] == 9
    assert walks["demo-0"] == 0


def test_a_report_apart_pair_is_never_seated_together():
    people = [*five_regulars(), person("demo-a"), person("demo-b")]
    people = [p for p in people if p["uid"] != "demo-0"]  # demo-1..4, demo-a, demo-b

    result = solve_checked(problem(people, avoid=[("demo-a", "demo-b")], barrios=SOLYMAR_SUR_ONLY))

    [members] = members_of(result).values()
    assert not {"demo-a", "demo-b"} <= set(members)
    assert len(members) == 5


def sizes(result):
    return sorted(len(r["members"]) for r in result["proposals"])


def test_three_neighbours_are_too_few_to_open_a_ronda():
    result = solve_checked(problem(five_regulars()[:3], barrios=SOLYMAR_SUR_ONLY))

    assert result["proposals"] == []
    assert result["unseated"] == ["demo-0", "demo-1", "demo-2"]


def test_futbol_5_seats_ten_and_waitlists_the_rest():
    players = [person(f"demo-{i:02}", pretexts=("futbol5",)) for i in range(12)]

    result = solve_checked(problem(players, barrios=SOLYMAR_SUR_ONLY))

    assert sizes(result) == [10]
    assert len(result["unseated"]) == 2


def test_seven_futbol_players_are_too_few_for_a_match():
    players = [person(f"demo-{i}", pretexts=("futbol5",)) for i in range(7)]

    result = solve_checked(problem(players, barrios=SOLYMAR_SUR_ONLY))

    assert result["proposals"] == []


def test_ten_mate_neighbours_split_five_and_five_rather_than_six_and_four():
    both_days = ("sat-afternoon", "sun-morning")
    people = [person(f"demo-{i}", slots=both_days) for i in range(10)]

    result = solve_checked(problem(people, barrios=SOLYMAR_SUR_ONLY))

    assert sizes(result) == [5, 5]


def test_nobody_is_the_only_one_of_their_age_band_even_if_a_neighbour_walks_further():
    thirties = [person(f"demo-t{i}", age_band="30-39") for i in range(5)]
    # Nine blocks away: seating one of them instead of a fifth thirty-something walks less.
    sixties = [person(f"demo-s{i}", age_band="60-69", barrio="solymar-norte") for i in range(2)]

    result = solve_checked(problem([*thirties, *sixties]))

    [members] = members_of(result).values()
    assert {"demo-s0", "demo-s1"} <= set(members)
    assert len(members) == 6


def ronda_of(result, uid):
    return next(
        (r["id"] for r in result["proposals"] if uid in {m["uid"] for m in r["members"]}), None
    )


def test_a_plus_one_pair_is_seated_together_even_if_that_leaves_a_ronda_short():
    saturday = [person(f"demo-sat{i}") for i in range(4)]
    sunday = [person(f"demo-sun{i}", slots=("sun-morning",)) for i in range(4)]
    ana = person("demo-ana", slots=("sat-afternoon", "sun-morning"), plus_one="demo-beto")
    beto = person("demo-beto", slots=("sun-morning",))

    result = solve_checked(problem([*saturday, *sunday, ana, beto], barrios=SOLYMAR_SUR_ONLY))

    assert ronda_of(result, "demo-ana") == ronda_of(result, "demo-beto") is not None


def test_a_ronda_holds_at_most_one_plus_one_pair_even_if_a_pair_walks_further():
    sat_sur, sun_norte = "solymar-sur_mate_sat-afternoon", "solymar-norte_mate_sun-morning"
    both_days = ("sat-afternoon", "sun-morning")
    ana = person("demo-ana", slots=both_days, eligible=[sat_sur, sun_norte], plus_one="demo-beto")
    beto = person("demo-beto", slots=both_days, eligible=[sat_sur, sun_norte])
    carla = person("demo-carla", eligible=[sat_sur], plus_one="demo-dani")
    dani = person("demo-dani", eligible=[sat_sur])
    saturday = [person(f"demo-sat{i}", eligible=[sat_sur]) for i in range(2)]
    sunday = [
        person(f"demo-sun{i}", barrio="solymar-norte", slots=("sun-morning",), eligible=[sun_norte])
        for i in range(4)
    ]

    result = solve_checked(problem([ana, beto, carla, dani, *saturday, *sunday]))

    assert ronda_of(result, "demo-ana") == ronda_of(result, "demo-beto") == sun_norte
    assert ronda_of(result, "demo-carla") == ronda_of(result, "demo-dani") == sat_sur


def bands_by_ronda(result):
    return {r["id"]: sorted(m["ageBand"] for m in r["members"]) for r in result["proposals"]}


def test_truco_gives_each_under_30_an_over_60_partner_even_if_some_walk_further():
    young = [
        person(f"demo-y{i}", age_band="18-29", barrio="solymar-norte", pretexts=("truco",))
        for i in range(4)
    ]
    old = [person(f"demo-o{i}", age_band="60-69", pretexts=("truco",)) for i in range(4)]

    result = solve_checked(problem([*young, *old]))

    assert bands_by_ronda(result) == {
        "solymar-norte_truco_sat-afternoon": ["18-29", "18-29", "60-69", "60-69"],
        "solymar-sur_truco_sat-afternoon": ["18-29", "18-29", "60-69", "60-69"],
    }


def test_a_neighbour_takes_the_seat_in_their_own_barrio_over_one_nine_blocks_away():
    sur = five_regulars()
    norte = [person(f"demo-n{i}", barrio="solymar-norte") for i in range(5)]
    undecided = person("demo-x", barrio="solymar-norte")

    result = solve_checked(problem([*sur, *norte, undecided]))

    assert ronda_of(result, "demo-x") == "solymar-norte_mate_sat-afternoon"


def test_each_ronda_says_which_soft_rules_it_keeps():
    one_younger = person("demo-x", age_band="30-39")
    people = [*five_regulars()[:4], one_younger]

    result = solve_checked(problem(people, barrios=SOLYMAR_SUR_ONLY))

    [ronda] = result["proposals"]
    assert ronda["checks"] == {
        "twoPerAgeBand": False,
        "sizeForPretext": True,
        "plusOneTogether": True,
        "onePlusOnePair": True,
        "trucoCrossAge": True,
        "nearbyFirst": True,
    }


def test_the_rejected_alternative_is_the_best_grouping_that_breaks_a_soft_rule_and_names_it():
    thirties = [person(f"demo-t{i}", age_band="30-39") for i in range(5)]
    sixties = [person(f"demo-s{i}", age_band="60-69", barrio="solymar-norte") for i in range(2)]
    data = problem([*thirties, *sixties])

    alternative = solve_checked(data)["rejectedAlternative"]

    # Five thirty-somethings and one sixty-something walk less, but leave the 60+ alone.
    [ronda] = alternative["proposals"]
    assert sorted(m["ageBand"] for m in ronda["members"]) == ["30-39"] * 5 + ["60-69"]
    assert alternative["brokenRule"] == "twoPerAgeBand"
    assert alternative["objectiveLoss"] == 120 - 9 * 5


def test_there_is_no_rejected_alternative_when_nobody_can_be_seated():
    result = solve_checked(problem(five_regulars()[:3], barrios=SOLYMAR_SUR_ONLY))

    assert result["rejectedAlternative"] is None


def test_sixty_somethings_and_seventy_somethings_count_as_one_age_band_of_60_plus():
    # docs/PRODUCT.md's check reads "Hay al menos dos de 60 o más".
    people = [
        *(person(f"demo-{i}", age_band="30-39") for i in range(3)),
        person("demo-60", age_band="60-69"),
        person("demo-70", age_band="70-79"),
    ]

    result = solve_checked(problem(people, barrios=SOLYMAR_SUR_ONLY))

    [ronda] = result["proposals"]
    assert ronda["checks"]["twoPerAgeBand"] is True


def test_a_truco_ronda_with_no_under_30s_needs_no_cross_age_partners():
    players = [person(f"demo-{i}", age_band="70-79", pretexts=("truco",)) for i in range(6)]

    result = solve_checked(problem(players, barrios=SOLYMAR_SUR_ONLY))

    [ronda] = result["proposals"]
    assert ronda["checks"]["trucoCrossAge"] is True
