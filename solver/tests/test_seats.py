"""The seat catalogue (seats.py): one document per barrio and pretext, for every barrio."""

from ronda_solver.barrios import COSTA_BARRIOS
from ronda_solver.montevideo import MONTEVIDEO_BARRIOS
from ronda_solver.seats import PRETEXTS, catalogue, version


def test_has_every_barrio_and_pretext():
    documents = catalogue()

    barrios = len(COSTA_BARRIOS) + len(MONTEVIDEO_BARRIOS)
    assert len(documents) == barrios * len(PRETEXTS) == 71 * 7
    assert "palermo_mate" in documents and "solymar-sur_pajaros" in documents


def test_a_seat_has_no_slot_and_walks_from_its_own_area():
    seat = catalogue()["palermo_mate"]

    assert seat.keys() == {"barrio", "pretext", "blocksFrom", "hasStairs", "needsCar"}
    assert (seat["barrio"], seat["pretext"]) == ("palermo", "mate")
    assert seat["blocksFrom"]["palermo"] == 0.0
    assert 9 < seat["blocksFrom"]["parque-rodo"] < 11
    assert seat["blocksFrom"].keys() == MONTEVIDEO_BARRIOS.keys()
    assert not seat["hasStairs"] and not seat["needsCar"]


def test_the_costa_walks_only_from_the_costa():
    seat = catalogue()["solymar-sur_mate"]

    assert seat["blocksFrom"].keys() == COSTA_BARRIOS.keys()


def test_the_version_follows_the_documents():
    documents = catalogue()
    changed = {**documents, "palermo_mate": {**documents["palermo_mate"], "hasStairs": True}}

    assert version(documents) == version(catalogue())
    assert version(changed) != version(documents)
    assert len(version(documents)) == 16
