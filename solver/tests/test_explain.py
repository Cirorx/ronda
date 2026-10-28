"""Why the rejected alternative was rejected: the rules it breaks, structured and in Spanish."""

import json
from pathlib import Path

import pytest

from ronda_solver import check, explain, score, solve
from ronda_solver.demo import invented_problem
from ronda_solver.spanish import in_spanish
from tests.builders import BARRIOS, grouping, person, problem, ronda

FIXTURE = Path(__file__).parent.parent / "fixtures" / "invented_demo_30.json"


def test_on_the_thirty_person_fixture_the_alternative_is_rejected_for_18_more_blocks_walked():
    # The winner and the alternative both leave three people alone in their age group; only the
    # walk differs: the truco ronda moves nine blocks for four people instead of for two.
    data = json.loads(FIXTURE.read_text())

    alternative = solve(data)["rejectedAlternative"]

    assert alternative["reason"] == "Alternativa B rechazada: hace caminar 18 cuadras más."
    [reason] = alternative["reasons"]
    assert reason["rule"] == "nearbyFirst"
    assert reason["hard"] is False
    assert reason["units"] == 18
    assert reason["loss"] == 90


def is_broken_more(data, result, alternative, reason):
    """Checks a named rule against the scorer and checker, not the explanation's own diff."""
    if reason["hard"]:
        return reason["rule"] in {v["rule"] for v in check(data, alternative)}
    kept, broken = score(data, result), score(data, alternative)
    if reason["rule"] == "fewerSeated":
        return broken["seated"] < kept["seated"]
    return broken["units"][reason["rule"]] > kept["units"][reason["rule"]]


@pytest.mark.parametrize("seed", [23, 1, 2, 3, 4, 5])
def test_every_rejected_alternative_of_thirty_invented_neighbours_names_a_rule_it_breaks(seed):
    # Seed 23 is fixtures/invented_demo_30.json.
    data = invented_problem(30, seed)

    result = solve(data)
    alternative = result["rejectedAlternative"]

    assert alternative["reasons"]
    assert alternative["reason"].startswith("Alternativa B rechazada: ")
    assert alternative["brokenRule"] == alternative["reasons"][0]["rule"]
    for reason in alternative["reasons"]:
        assert reason["violations"]
        assert is_broken_more(data, result, alternative, reason)


def test_an_alternative_that_leaves_a_60_plus_alone_says_so_and_names_who():
    thirties = [person(f"demo-t{i}", age_band="30-39") for i in range(5)]
    sixties = [person(f"demo-s{i}", age_band="60-69", barrio="solymar-norte") for i in range(2)]

    alternative = solve(problem([*thirties, *sixties]))["rejectedAlternative"]

    # It walks 9 blocks less, but leaves one 60+ alone: walking less is no reason to reject it.
    assert alternative["reason"] == (
        "Alternativa B rechazada: hay una sola persona de 60 o más en una ronda."
    )
    [ronda] = alternative["proposals"]
    [lone_sixty] = [m["uid"] for m in ronda["members"] if m["ageBand"] == "60-69"]
    assert alternative["reasons"] == [
        {
            "rule": "twoPerAgeBand",
            "hard": False,
            "units": 1,
            "loss": 120,
            "violations": [
                {
                    "rondaId": "solymar-sur_mate_sat-afternoon",
                    "uids": [lone_sixty],
                    "params": {"ageGroup": "60plus"},
                }
            ],
        }
    ]


SOLYMAR_SUR_ONLY = {"solymar-sur": BARRIOS["solymar-sur"]}


def test_an_alternative_that_seats_fewer_says_how_many_it_leaves_without_a_seat():
    regulars = [person(f"demo-{i}") for i in range(5)]

    result = solve(problem(regulars, barrios=SOLYMAR_SUR_ONLY))
    alternative = result["rejectedAlternative"]

    # The only other grouping seats four: one more without a seat, and a seat short of five.
    assert alternative["reason"] == "Alternativa B rechazada: deja a una persona más sin lugar."
    fewer, short = alternative["reasons"]
    assert (fewer["rule"], fewer["units"], fewer["loss"]) == ("fewerSeated", 1, 1000)
    assert fewer["violations"] == [{"rondaId": None, "uids": alternative["unseated"], "params": {}}]
    assert (short["rule"], short["units"], short["loss"]) == ("sizeForPretext", 1, 100)
    assert short["violations"][0]["params"] == {"pretext": "mate", "members": 4, "target": 5}


BOTH_DAYS = ("sat-afternoon", "sun-afternoon")


def test_a_ronda_left_short_of_its_target_says_how_many_it_has_and_how_many_are_ideal():
    data = problem([person(f"demo-{i}", slots=BOTH_DAYS) for i in range(10)])
    uids = [p["uid"] for p in data["people"]]
    five_and_five = grouping(data, ronda(uids[:5]), ronda(uids[5:], slot="sun-afternoon"))
    six_and_four = grouping(data, ronda(uids[:6]), ronda(uids[6:], slot="sun-afternoon"))

    explained = explain(data, five_and_five, six_and_four)

    assert explained["reason"] == (
        "Alternativa B rechazada: una ronda de mate queda con 4 y lo ideal son 5."
    )
    assert explained["reasons"] == [
        {
            "rule": "sizeForPretext",
            "hard": False,
            "units": 1,
            "loss": 100,
            "violations": [
                {
                    "rondaId": "solymar-sur_mate_sun-afternoon",
                    "uids": [],
                    "params": {"pretext": "mate", "members": 4, "target": 5},
                }
            ],
        }
    ]


def only_reason(data, winner, alternative):
    explained = explain(data, winner, alternative)
    [reason] = explained["reasons"]
    return reason, explained["reason"]


def test_an_alternative_that_splits_a_plus_one_pair_says_so_and_names_the_pair():
    data = problem(
        [
            person("demo-ana", plus_one="demo-beto"),
            person("demo-beto"),
            *(person(f"demo-{i}") for i in range(4)),
        ]
    )
    together = grouping(data, ronda(["demo-ana", "demo-beto", "demo-0", "demo-1", "demo-2"]))
    apart = grouping(data, ronda(["demo-ana", "demo-0", "demo-1", "demo-2", "demo-3"]))

    reason, sentence = only_reason(data, together, apart)

    assert sentence == "Alternativa B rechazada: separa a alguien de su invitado."
    assert (reason["rule"], reason["units"], reason["loss"]) == ("plusOneTogether", 1, 300)
    assert reason["violations"] == [
        {
            "rondaId": "solymar-sur_mate_sat-afternoon",
            "uids": ["demo-ana", "demo-beto"],
            "params": {},
        }
    ]


def test_an_alternative_with_two_plus_one_pairs_in_one_ronda_says_so():
    data = problem(
        [
            person("demo-ana", plus_one="demo-beto"),
            person("demo-beto"),
            person("demo-carla", plus_one="demo-dani"),
            person("demo-dani"),
            *(person(f"demo-{i}") for i in range(3)),
        ]
    )
    one_pair = grouping(data, ronda(["demo-ana", "demo-beto", "demo-0", "demo-1", "demo-2"]))
    two_pairs = grouping(
        data, ronda(["demo-ana", "demo-beto", "demo-carla", "demo-dani", "demo-0"])
    )

    reason, sentence = only_reason(data, one_pair, two_pairs)

    assert sentence == (
        "Alternativa B rechazada: pone a 2 personas con su invitado en la misma ronda."
    )
    assert (reason["rule"], reason["units"], reason["loss"]) == ("onePlusOnePair", 1, 200)
    assert reason["violations"][0]["params"] == {"pairs": 2}


def test_an_alternative_that_leaves_under_30s_without_a_60_plus_truco_partner_says_how_many():
    young = [person(f"demo-y{i}", age_band="18-29", pretexts=("truco",)) for i in range(4)]
    old = [person(f"demo-o{i}", age_band="60-69", pretexts=("truco",)) for i in range(2)]
    middle = [person(f"demo-m{i}", age_band="40-49", pretexts=("truco",)) for i in range(2)]
    data = problem([*young, *old, *middle])
    partnered = grouping(
        data,
        ronda(["demo-y0", "demo-y1", "demo-o0", "demo-o1", "demo-m0", "demo-m1"], pretext="truco"),
    )
    two_partnerless = grouping(
        data,
        ronda(["demo-y0", "demo-y1", "demo-y2", "demo-y3", "demo-o0", "demo-o1"], pretext="truco"),
    )

    reason, sentence = only_reason(data, partnered, two_partnerless)

    assert sentence == (
        "Alternativa B rechazada: deja a 2 personas de menos de 30 sin compañero de 60 o más "
        "en el truco."
    )
    assert (reason["rule"], reason["units"], reason["loss"]) == ("trucoCrossAge", 2, 120)
    assert reason["violations"][0]["uids"] == ["demo-y0", "demo-y1", "demo-y2", "demo-y3"]


# Hard rules. The solver's own alternative never breaks one; an alternative built elsewhere (an
# admin's edit, say) can, and then the hard rule is the reason, whatever the soft rules say.

FIVE = [person(f"demo-{i}") for i in range(5)]
FIVE_UIDS = [p["uid"] for p in FIVE]
RONDA_ID = "solymar-sur_mate_sat-afternoon"


def hard_reasons(data, alternative):
    winner = grouping(data, ronda(FIVE_UIDS))
    explained = explain(data, winner, alternative)
    assert all(r["hard"] and r["loss"] is None for r in explained["reasons"])
    return explained


@pytest.mark.parametrize(
    ("intruder", "rule", "sentence"),
    [
        (
            person("demo-x", eligible=[]),
            "eligibleSeat",
            "pone a alguien en un lugar que no le sirve",
        ),
        (
            person("demo-x", slots=("sun-morning",), eligible=[RONDA_ID]),
            "sameSlot",
            "pone a alguien en un día y horario que no eligió",
        ),
        (
            person("demo-x", pretexts=("truco",), eligible=[RONDA_ID]),
            "samePretext",
            "pone a alguien en una actividad que no eligió",
        ),
        (
            person("demo-x", barrio="el-pinar-sur"),
            "withinTenBlocks",
            "pone a alguien a más de 10 cuadras de su barrio",
        ),
    ],
)
def test_a_seat_the_neighbour_may_not_take_is_the_reason(intruder, rule, sentence):
    data = problem([*FIVE, intruder])

    explained = hard_reasons(data, grouping(data, ronda([*FIVE_UIDS, "demo-x"])))

    assert explained["reason"] == f"Alternativa B rechazada: {sentence}."
    assert explained["reasons"] == [
        {
            "rule": rule,
            "hard": True,
            "units": 1,
            "loss": None,
            "violations": [{"rondaId": RONDA_ID, "uids": ["demo-x"], "params": {}}],
        }
    ]


def test_a_report_apart_pair_seated_together_is_the_reason_even_if_it_seats_one_more():
    data = problem([*FIVE, person("demo-a"), person("demo-b")], avoid=[("demo-a", "demo-b")])

    explained = hard_reasons(data, grouping(data, ronda([*FIVE_UIDS[:4], "demo-a", "demo-b"])))

    assert explained["reason"] == "Alternativa B rechazada: junta a dos personas que separaste."
    [reason] = explained["reasons"]
    assert reason["violations"] == [
        {"rondaId": RONDA_ID, "uids": ["demo-a", "demo-b"], "params": {}}
    ]


@pytest.mark.parametrize(
    ("size", "sentence", "params"),
    [
        (3, "abre una ronda de mate con 3 y hacen falta 4", {"members": 3}),
        (7, "una ronda de mate queda con 7 y el máximo es 6", {"members": 7}),
    ],
)
def test_a_ronda_outside_its_size_bounds_says_its_size_and_the_bound(size, sentence, params):
    data = problem([person(f"demo-{i}") for i in range(7)])

    explained = hard_reasons(data, grouping(data, ronda([f"demo-{i}" for i in range(size)])))

    assert explained["reason"] == f"Alternativa B rechazada: {sentence}."
    [reason] = explained["reasons"]
    assert reason["rule"] == "sizeBounds"
    assert reason["violations"][0]["params"] == {"pretext": "mate", "floor": 4, "cap": 6, **params}


def test_a_neighbour_in_two_rondas_at_once_is_the_reason():
    both = person("demo-x", slots=("sat-afternoon", "sun-morning"))
    sunday = [person(f"demo-s{i}", slots=("sun-morning",)) for i in range(4)]
    data = problem([*FIVE, both, *sunday])
    sunday_uids = [p["uid"] for p in sunday]
    twice = grouping(
        data,
        ronda([*FIVE_UIDS[:4], "demo-x"]),
        ronda([*sunday_uids, "demo-x"], slot="sun-morning"),
    )

    explained = hard_reasons(data, twice)

    assert explained["reason"] == "Alternativa B rechazada: pone a alguien en dos lugares a la vez."
    assert explained["reasons"][0]["violations"] == [
        {"rondaId": None, "uids": ["demo-x"], "params": {"places": 2}}
    ]


def test_a_neighbour_missing_from_the_alternative_is_the_reason():
    data = problem(FIVE)
    forgotten = {"proposals": [], "unseated": FIVE_UIDS[1:]}

    explained = hard_reasons(data, forgotten)

    assert explained["reason"] == "Alternativa B rechazada: se olvida de alguien."
    assert explained["reasons"][0]["violations"] == [
        {"rondaId": None, "uids": ["demo-0"], "params": {"places": 0}}
    ]


def test_a_member_who_never_signed_up_has_no_eligible_seat():
    data = problem(FIVE)

    explained = hard_reasons(data, grouping(data, ronda([*FIVE_UIDS, "demo-ghost"])))

    assert explained["reasons"][0]["rule"] == "eligibleSeat"
    assert explained["reasons"][0]["violations"][0]["uids"] == ["demo-ghost"]


def test_an_alternative_breaking_two_hard_rules_is_rejected_for_a_rule_it_breaks():
    # CP-SAT returns a set of rules sufficient to rule it out, not necessarily every one.
    data = problem([*FIVE, person("demo-far", barrio="el-pinar-sur")], avoid=[("demo-0", "demo-1")])
    alternative = grouping(data, ronda([*FIVE_UIDS, "demo-far"]))

    explained = hard_reasons(data, alternative)

    named = {r["rule"] for r in explained["reasons"]}
    assert named
    assert named <= {"withinTenBlocks", "avoidPairApart"}


def test_an_alternative_no_worse_than_the_winner_has_no_reason():
    data = problem(FIVE)
    winner = grouping(data, ronda(FIVE_UIDS))

    assert explain(data, winner, winner) == {"reasons": [], "reason": None}


@pytest.mark.parametrize(
    ("rule", "units", "params", "sentence"),
    [
        (
            "twoPerAgeBand",
            1,
            {"ageGroup": "under30"},
            "hay una sola persona de menos de 30 en una ronda",
        ),
        (
            "twoPerAgeBand",
            1,
            {"ageGroup": "30to59"},
            "hay una sola persona de 30 a 59 en una ronda",
        ),
        ("twoPerAgeBand", 1, {"ageGroup": "90-99"}, "hay una sola persona de 90-99 en una ronda"),
        (
            "sizeForPretext",
            2,
            {"pretext": "futbol5", "members": 8, "target": 10},
            "una ronda de fútbol 5 queda con 8 y lo ideal son 10",
        ),
        (
            "trucoCrossAge",
            1,
            {},
            "deja a una persona de menos de 30 sin compañero de 60 o más en el truco",
        ),
        ("nearbyFirst", 1, {"blocks": 1}, "hace caminar una cuadra más"),
        ("fewerSeated", 3, {}, "deja a 3 personas más sin lugar"),
    ],
)
def test_each_reason_reads_as_one_plain_sentence(rule, units, params, sentence):
    reason = {"rule": rule, "units": units, "violations": [{"params": params}]}

    assert in_spanish(reason) == f"Alternativa B rechazada: {sentence}."
