import json
import re
from datetime import datetime
from pathlib import Path

import pytest

import demo_data

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "solver" / "fixtures" / "invented_demo_30.json"
RULES = (ROOT / "firestore.rules").read_text()
INVENTED_SEATS = json.loads((ROOT / "data" / "demo" / "invented_seat_facts.json").read_text())

BARRIOS = {
    "shangrila", "san-jose-de-carrasco", "lagomar-sur", "lagomar-norte", "solymar-sur",
    "solymar-norte", "lomas-de-solymar", "el-pinar-sur", "el-pinar-norte",
}  # fmt: skip
"""The app's `Barrio` ids (packages/profile_repository/lib/src/models/barrio.dart)."""


def _rules_list(pattern: str) -> set[str]:
    """The quoted strings of the first `[...]` list in firestore.rules after `pattern`."""
    match = re.search(pattern + r"\(?\[(.*?)\]", RULES, re.DOTALL)
    assert match, pattern
    return set(re.findall(r"'([^']+)'", match.group(1)))


USER_FIELDS = _rules_list(r"function isUserDocument.*?hasOnly")
AGE_BANDS = _rules_list(r"data\.ageBand in ")


def _collection(documents: dict, path_pattern: str) -> dict[str, dict]:
    return {path: fields for path, fields in documents.items() if re.fullmatch(path_pattern, path)}


@pytest.fixture(scope="module", params=demo_data.SET_SIZES, ids=lambda n: f"{n} people")
def state(request):
    return demo_data.documents(request.param)


@pytest.fixture(scope="module")
def thirty():
    return demo_data.documents(30)


def test_the_thirty_sign_ups_are_the_solver_fixture_people(thirty):
    fixture = json.loads(FIXTURE.read_text())

    users = _collection(thirty, r"users/[^/]+")
    assert sorted(users) == [f"users/{person['uid']}" for person in fixture["people"]]
    for person in fixture["people"]:
        user = users[f"users/{person['uid']}"]
        eligible = thirty[f"users/{person['uid']}/private/eligible"]
        assert user["ageBand"] == person["ageBand"]
        assert user["barrio"] == person["barrio"]
        assert sorted(user["pretexts"]) == person["pretexts"]
        assert sorted(user["slots"]) == person["slots"]
        assert user.get("plusOneUid") == person.get("plusOneUid")
        assert eligible["seatIds"] == person["eligibleSeatIds"]


def test_the_thirty_hold_a_few_plus_one_pairs_and_the_fixture_avoid_pair(thirty):
    plus_ones = [u for u in _collection(thirty, r"users/[^/]+").values() if "plusOneUid" in u]

    assert 2 <= len(plus_ones) <= 8
    assert _collection(thirty, r"avoid/.+") == {
        "avoid/demo-005_demo-006": {"uidA": "demo-005", "uidB": "demo-006"},
    }


def test_the_two_hundred_are_demo_uids_one_to_two_hundred():
    users = _collection(demo_data.documents(200), r"users/[^/]+")

    assert sorted(users) == [f"users/demo-{n:03}" for n in range(1, 201)]


def test_only_the_thirty_and_two_hundred_sets_exist():
    with pytest.raises(ValueError, match="30, 200"):
        demo_data.documents(31)


def test_every_user_document_passes_the_rules_field_checks(state):
    for path, user in _collection(state, r"users/[^/]+").items():
        assert set(user) <= USER_FIELDS, path
        assert isinstance(user["firstName"], str)
        assert 1 <= len(user["firstName"]) <= 30
        assert user["ageBand"] in AGE_BANDS
        assert set(user["terms"]) == {"version", "acceptedAt"}
        assert isinstance(user["terms"]["acceptedAt"], datetime)
        assert isinstance(user["createdAt"], datetime)


def test_every_user_document_holds_the_app_ids_in_the_order_the_app_stores_them(state):
    slots = [f"{d}-{b}" for d in ("mon", "tue", "wed", "thu", "fri", "sat", "sun")
             for b in ("morning", "afternoon", "evening")]  # fmt: skip
    pretexts = ["mate", "truco", "futbol5", "caminata"]
    brings = ["pan", "yerba", "termo", "sillas", "enseno-truco", "tengo-ganas"]

    for path, user in _collection(state, r"users/[^/]+").items():
        assert user["barrio"] in BARRIOS, path
        assert user["slots"] == [s for s in slots if s in user["slots"]], path
        assert user["pretexts"] == [p for p in pretexts if p in user["pretexts"]], path
        assert user["brings"] == [b for b in brings if b in user["brings"]], path
        assert user["slots"] and user["pretexts"] and user["brings"], path
        assert user["terms"]["version"] == "2026-10-27"


def test_tengo_ganas_comes_alone(state):
    for user in _collection(state, r"users/[^/]+").values():
        assert "tengo-ganas" not in user["brings"] or user["brings"] == ["tengo-ganas"]


def test_the_thirty_have_thirty_different_first_names(thirty):
    names = [u["firstName"] for u in _collection(thirty, r"users/[^/]+").values()]

    assert len(set(names)) == 30


def test_the_thirty_keep_their_names_and_brings_in_the_two_hundred(thirty):
    two_hundred = demo_data.documents(200)

    for path, user in _collection(thirty, r"users/[^/]+").items():
        assert two_hundred[path]["firstName"] == user["firstName"], path
        assert two_hundred[path]["brings"] == user["brings"], path


def test_the_eligible_document_is_exactly_seat_ids_and_when(state):
    eligible = _collection(state, r"users/[^/]+/private/eligible")

    assert len(eligible) == len(_collection(state, r"users/[^/]+"))
    for path, fields in eligible.items():
        assert set(fields) == {"seatIds", "updatedAt"}, path
        assert all(isinstance(seat_id, str) for seat_id in fields["seatIds"])
        assert len(fields["seatIds"]) <= 1000


def test_nothing_but_the_profile_and_eligible_ids_sits_under_a_user(state):
    under_users = {p for p in state if p.startswith("users/")}

    assert under_users == {
        *_collection(state, r"users/[^/]+"),
        *_collection(state, r"users/[^/]+/private/eligible"),
    }


def test_no_document_carries_needs_mood_or_audio(state):
    def keys(value):
        if isinstance(value, dict):
            for key, inner in value.items():
                yield key
                yield from keys(inner)

    for path, fields in state.items():
        assert not set(keys(fields)) & {"needs", "mood", "audio"}, path


def test_every_seat_anyone_lists_has_seat_facts_with_a_walk_from_every_barrio(state):
    listed = {
        seat_id
        for fields in _collection(state, r"users/[^/]+/private/eligible").values()
        for seat_id in fields["seatIds"]
    }

    for seat_id in listed:
        facts = state.get(f"seat_facts/{seat_id}")
        assert facts, seat_id
        assert set(facts["blocksFrom"]) == BARRIOS, seat_id


def test_seat_facts_cover_every_barrio_pretext_and_demo_slot():
    seats = _collection(demo_data.documents(30), r"seat_facts/.+")

    assert len(seats) == 9 * 4 * 4
    for path, facts in seats.items():
        assert path == f"seat_facts/{facts['barrio']}_{facts['pretext']}_{facts['slot']}"
        assert set(facts) == {
            "barrio", "pretext", "slot", "blocksFrom", "hasStairs", "endsAfterDark",
            "needsCar", "updatedAt",
        }  # fmt: skip


def test_the_hand_made_seats_are_seeded_as_written(thirty):
    for seat_id, facts in INVENTED_SEATS["seats"].items():
        assert thirty[f"seat_facts/{seat_id}"] == {**facts, "updatedAt": demo_data.DEMO_TIME}


def test_generated_seats_follow_the_hand_made_file_formula():
    """Walks, slot and darkness agree with the file; only a host-set place differs."""
    for seat_id, facts in INVENTED_SEATS["seats"].items():
        twin = demo_data.generated_seat_facts([facts["pretext"]], [facts["slot"]])[seat_id]
        for field in ("barrio", "pretext", "slot", "blocksFrom", "endsAfterDark"):
            assert twin[field] == facts[field], (seat_id, field)


def test_a_generated_evening_seat_ends_after_dark_and_has_no_place_yet(thirty):
    seat = thirty["seat_facts/shangrila_truco_thu-evening"]

    assert seat["endsAfterDark"] is True
    assert seat["hasStairs"] is False
    assert seat["needsCar"] is False
    assert seat["blocksFrom"]["shangrila"] == 0.0
    assert seat["blocksFrom"]["san-jose-de-carrasco"] == 19.1
    assert seat["blocksFrom"]["el-pinar-norte"] == 125.3


def test_every_timestamp_is_the_one_demo_moment(state):
    def timestamps(value):
        if isinstance(value, dict):
            for inner in value.values():
                yield from timestamps(inner)
        elif isinstance(value, datetime):
            yield value

    stamps = {stamp for fields in state.values() for stamp in timestamps(fields)}
    assert stamps == {demo_data.DEMO_TIME}
    assert demo_data.DEMO_TIME.utcoffset() is not None
