"""Every copy of the barrio list matches `ronda_solver.barrios`: the app's `Barrio` enum, the
public pages' names and picker, and the module montevideo_barrios.py writes."""

import ast
import re

import demo_data
import montevideo_barrios

# isort: split
from ronda_solver.barrios import BARRIO_NAMES, CENTROIDS, COSTA_BARRIOS
from ronda_solver.geo import blocks_between
from ronda_solver.montevideo import MONTEVIDEO_BARRIOS
from ronda_solver.rules import MAX_WALK_BLOCKS, MONTEVIDEO_WALK_BLOCKS

ROOT = demo_data.ROOT

DART = (ROOT / "packages/profile_repository/lib/src/models/barrio.dart").read_text()
JS = (ROOT / "hosting/assets/ronda.js").read_text()
HTML = (ROOT / "hosting/index.html").read_text()


def test_there_are_the_costa_nine_and_montevideo_62_with_kebab_ids():
    assert len(COSTA_BARRIOS) == 9
    assert len(MONTEVIDEO_BARRIOS) == 62
    assert len(BARRIO_NAMES) == 71
    assert all(re.fullmatch(r"[a-z]+(-[a-z]+)*", barrio) for barrio in BARRIO_NAMES)
    assert BARRIO_NAMES["barrio-sur"] == "Barrio Sur"


def test_the_generated_module_is_the_script_s_list_in_its_order():
    assert {b: name for b, (name, _, _) in MONTEVIDEO_BARRIOS.items()} == montevideo_barrios.BARRIOS
    for lat, lng in CENTROIDS.values():
        assert -35.0 < lat < -34.6 and -56.5 < lng < -55.8


def test_the_app_enum_has_every_id_and_name():
    entries = re.findall(r"\w+\(\s*'([a-z-]+)',\s*'([^']+)',\s*BarrioArea\.(\w+),?\s*\)", DART)
    assert {barrio: name for barrio, name, _ in entries} == BARRIO_NAMES
    assert len(entries) == 71
    assert {b for b, _, area in entries if area == "costa"} == set(COSTA_BARRIOS)


def test_the_app_walks_as_far_as_the_solver():
    assert f"montevideo ? {MONTEVIDEO_WALK_BLOCKS} : defaultWalkBlocks" in DART
    assert f"defaultWalkBlocks = {MAX_WALK_BLOCKS};" in DART


def test_the_public_pages_have_every_id_and_name():
    table = re.search(r"export const BARRIOS = (\{.*?\});", JS, re.DOTALL)[1]
    assert ast.literal_eval(table) == BARRIO_NAMES
    options = dict(re.findall(r'<option value="([a-z-]+)">([^<]+)</option>', HTML))
    assert options == BARRIO_NAMES


def test_neighbouring_montevideo_barrios_are_within_walking_distance():
    def blocks(a, b):
        return blocks_between(CENTROIDS[a], CENTROIDS[b])

    assert blocks("barrio-sur", "centro") <= MAX_WALK_BLOCKS
    assert blocks("barrio-sur", "palermo") <= MONTEVIDEO_WALK_BLOCKS
    assert blocks("pocitos", "punta-carretas") <= MONTEVIDEO_WALK_BLOCKS
    assert blocks("malvin", "punta-gorda") <= MONTEVIDEO_WALK_BLOCKS
    assert blocks("barrio-sur", "aguada") > MONTEVIDEO_WALK_BLOCKS
    assert blocks("carrasco", "shangrila") > MONTEVIDEO_WALK_BLOCKS
