"""The checker names every hard rule a result breaks. Results here are hand-written, not solved."""

import pytest

from ronda_solver import check
from tests.builders import person, problem

RONDA_ID = "solymar-sur_mate_sat-afternoon"


def ronda(uids, *, barrio="solymar-sur", pretext="mate", slot="sat-afternoon"):
    return {
        "id": f"{barrio}_{pretext}_{slot}",
        "barrio": barrio,
        "pretext": pretext,
        "slot": slot,
        "members": [{"uid": uid} for uid in uids],
    }


REGULARS = [person(f"demo-{i}") for i in range(5)]
REGULAR_UIDS = [p["uid"] for p in REGULARS]


def rules_broken(data, proposals, unseated=None):
    if unseated is None:
        seated = {m["uid"] for r in proposals for m in r["members"]}
        unseated = [p["uid"] for p in data["people"] if p["uid"] not in seated]
    result = {"proposals": proposals, "unseated": unseated}
    return [(v["rule"], v["rondaId"], v["uids"]) for v in check(data, result)]


def test_a_valid_ronda_breaks_no_hard_rule():
    assert rules_broken(problem(REGULARS), [ronda(REGULAR_UIDS)]) == []


@pytest.mark.parametrize(
    ("intruder", "rule"),
    [
        (person("demo-x", eligible=[]), "eligibleSeat"),
        (person("demo-x", slots=("sun-morning",), eligible=[RONDA_ID]), "sameSlot"),
        (person("demo-x", pretexts=("truco",), eligible=[RONDA_ID]), "samePretext"),
        (person("demo-x", barrio="el-pinar-sur"), "withinTenBlocks"),
    ],
)
def test_a_member_who_may_not_take_the_seat_is_named_with_the_rule(intruder, rule):
    data = problem([*REGULARS, intruder])

    assert rules_broken(data, [ronda([*REGULAR_UIDS, "demo-x"])]) == [(rule, RONDA_ID, ["demo-x"])]


def test_a_report_apart_pair_seated_together_is_named():
    data = problem(REGULARS, avoid=[("demo-0", "demo-1")])

    assert rules_broken(data, [ronda(REGULAR_UIDS)]) == [
        ("avoidPairApart", RONDA_ID, ["demo-0", "demo-1"])
    ]


def test_a_neighbour_in_two_rondas_is_named():
    both = person("demo-x", slots=("sat-afternoon", "sun-morning"))
    sunday = [person(f"demo-s{i}", slots=("sun-morning",)) for i in range(4)]
    data = problem([*REGULARS, both, *sunday])
    sunday_uids = [p["uid"] for p in sunday]

    broken = rules_broken(
        data,
        [ronda([*REGULAR_UIDS, "demo-x"]), ronda([*sunday_uids, "demo-x"], slot="sun-morning")],
    )

    assert broken == [("oneRondaEach", None, ["demo-x"])]


@pytest.mark.parametrize("size", [3, 7])
def test_a_ronda_outside_its_size_bounds_is_named(size):
    people = [person(f"demo-{i}") for i in range(size)]

    broken = rules_broken(problem(people), [ronda([p["uid"] for p in people])])

    assert broken == [("sizeBounds", RONDA_ID, [])]


def test_a_member_who_is_not_in_the_input_is_named():
    broken = rules_broken(problem(REGULARS), [ronda([*REGULAR_UIDS, "demo-ghost"])])

    assert broken == [("eligibleSeat", RONDA_ID, ["demo-ghost"])]


def test_a_neighbour_both_seated_and_unseated_is_named():
    broken = rules_broken(problem(REGULARS), [ronda(REGULAR_UIDS)], unseated=["demo-0"])

    assert broken == [("oneRondaEach", None, ["demo-0"])]


def test_a_neighbour_missing_from_the_result_is_named():
    data = problem([*REGULARS, person("demo-x")])

    broken = rules_broken(data, [ronda(REGULAR_UIDS)], unseated=[])

    assert broken == [("oneRondaEach", None, ["demo-x"])]
