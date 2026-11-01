# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = []
# ///
"""Write `solver/ronda_solver/montevideo.py`: the 62 barrios of Montevideo (the INE's official
list) with the point OpenStreetMap maps each one at.

One Overpass query for the named `place=suburb|neighbourhood` nodes inside the department of
Montevideo, run from here with a User-Agent (Overpass's rules). Each barrio takes the node in
`OSM_NODE`: where the INE joins two places in one barrio ("Capurro, Bella Vista"), the first
one's node; where OpenStreetMap has no node under the barrio's name, the node of the place
inside it that people name it by (Las Canteras by La Cruz de Carrasco). The data is
OpenStreetMap's, © its contributors, under the ODbL: the README credits it, and the generated
module names the node of every barrio so the numbers can be checked.

    python3 scripts/montevideo_barrios.py           # writes the module
    python3 scripts/montevideo_barrios.py --check   # exits 1 if OpenStreetMap moved a point

The output is committed; the download is not.
"""

import argparse
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

OVERPASS = "https://overpass-api.de/api/interpreter"
USER_AGENT = "Ronda-hackathon/0.1 (github.com/Cirorx/ronda)"
QUERY = (
    '[out:json][timeout:60];area["name"="Montevideo"]["admin_level"="4"]->.d;'
    'node(area.d)["place"~"^(suburb|neighbourhood)$"]["name"];out;'
)
OUT = Path(__file__).resolve().parents[1] / "solver" / "ronda_solver" / "montevideo.py"
DECIMALS = 4
"""About 10 m: a tenth of a block, finer than anything the solver measures."""

BARRIOS = {
    "ciudad-vieja": "Ciudad Vieja",
    "centro": "Centro",
    "barrio-sur": "Barrio Sur",
    "cordon": "Cordón",
    "palermo": "Palermo",
    "parque-rodo": "Parque Rodó",
    "punta-carretas": "Punta Carretas",
    "pocitos": "Pocitos",
    "buceo": "Buceo",
    "parque-batlle-villa-dolores": "Parque Batlle y Villa Dolores",
    "malvin": "Malvín",
    "malvin-norte": "Malvín Norte",
    "punta-gorda": "Punta Gorda",
    "carrasco": "Carrasco",
    "carrasco-norte": "Carrasco Norte",
    "banados-de-carrasco": "Bañados de Carrasco",
    "maronas-parque-guarani": "Maroñas y Parque Guaraní",
    "flor-de-maronas": "Flor de Maroñas",
    "las-canteras": "Las Canteras",
    "punta-de-rieles-bella-italia": "Punta de Rieles y Bella Italia",
    "jardines-del-hipodromo": "Jardines del Hipódromo",
    "ituzaingo": "Ituzaingó",
    "union": "Unión",
    "villa-espanola": "Villa Española",
    "mercado-modelo-bolivar": "Mercado Modelo y Bolívar",
    "castro-perez-castellanos": "Castro y Pérez Castellanos",
    "cerrito": "Cerrito",
    "las-acacias": "Las Acacias",
    "aires-puros": "Aires Puros",
    "casavalle": "Casavalle",
    "piedras-blancas": "Piedras Blancas",
    "manga-toledo-chico": "Manga y Toledo Chico",
    "paso-de-las-duranas": "Paso de las Duranas",
    "penarol-lavalleja": "Peñarol y Lavalleja",
    "cerro": "Cerro",
    "casabo-pajas-blancas": "Casabó y Pajas Blancas",
    "la-paloma-tomkinson": "La Paloma y Tomkinson",
    "la-teja": "La Teja",
    "prado-nueva-savona": "Prado y Nueva Savona",
    "capurro-bella-vista": "Capurro y Bella Vista",
    "aguada": "Aguada",
    "reducto": "Reducto",
    "atahualpa": "Atahualpa",
    "jacinto-vera": "Jacinto Vera",
    "la-figurita": "La Figurita",
    "larranaga": "Larrañaga",
    "la-blanqueada": "La Blanqueada",
    "villa-munoz-retiro": "Villa Muñoz y Retiro",
    "la-comercial": "La Comercial",
    "tres-cruces": "Tres Cruces",
    "brazo-oriental": "Brazo Oriental",
    "sayago": "Sayago",
    "conciliacion": "Conciliación",
    "belvedere": "Belvedere",
    "nuevo-paris": "Nuevo París",
    "tres-ombues-pueblo-victoria": "Tres Ombúes y Pueblo Victoria",
    "paso-de-la-arena": "Paso de la Arena",
    "colon-sureste-abayuba": "Colón Sureste y Abayubá",
    "colon-centro-noroeste": "Colón Centro y Noroeste",
    "lezica-melilla": "Lezica y Melilla",
    "villa-garcia-manga-rural": "Villa García y Manga Rural",
    "manga": "Manga",
}
"""The INE's 62 barrios, in its order; two places in one barrio joined with "y"."""

OSM_NODE = {
    "parque-batlle-villa-dolores": "Parque Batlle",
    "maronas-parque-guarani": "Maroñas",
    "las-canteras": "La Cruz de Carrasco",
    "punta-de-rieles-bella-italia": "Punta Rieles",
    "mercado-modelo-bolivar": "Bolívar",
    "castro-perez-castellanos": "Pérez Castellanos",
    "manga-toledo-chico": "Toledo Chico",
    "penarol-lavalleja": "Peñarol",
    "casabo-pajas-blancas": "Casabó",
    "la-paloma-tomkinson": "La Paloma Tomkinson",
    "prado-nueva-savona": "Prado",
    "capurro-bella-vista": "Capurro",
    "villa-munoz-retiro": "Villa Muñoz",
    "tres-ombues-pueblo-victoria": "Tres Ombúes",
    "colon-sureste-abayuba": "Barrio Abayubá",
    "colon-centro-noroeste": "Colón",
    "lezica-melilla": "Melilla",
    "villa-garcia-manga-rural": "Villa García",
}
"""The OpenStreetMap node name for a barrio whose own name has no node; the rest use theirs."""


def fetch() -> list[dict]:
    body = urllib.parse.urlencode({"data": QUERY}).encode()
    request = urllib.request.Request(OVERPASS, data=body, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=90) as response:
        return json.load(response)["elements"]


def points(nodes: list[dict]) -> dict[str, tuple[int, float, float]]:
    """Each barrio's (node id, lat, lng). A name OpenStreetMap maps twice takes its suburb."""
    by_name: dict[str, dict] = {}
    for node in sorted(nodes, key=lambda n: (n["tags"]["place"] != "suburb", n["id"])):
        by_name.setdefault(node["tags"]["name"], node)
    found = {}
    for barrio, name in BARRIOS.items():
        node = by_name.get(OSM_NODE.get(barrio, name))
        if node is None:
            sys.exit(f"no OpenStreetMap node for {barrio}")
        found[barrio] = (node["id"], round(node["lat"], DECIMALS), round(node["lon"], DECIMALS))
    return found


def module(found: dict[str, tuple[int, float, float]]) -> str:
    rows = "\n".join(
        f'    "{barrio}": ("{BARRIOS[barrio]}", {lat}, {lng}),  # node {node}'
        for barrio, (node, lat, lng) in found.items()
    )
    return f'''"""The 62 barrios of Montevideo (INE) with the point OpenStreetMap maps each at.

Generated by scripts/montevideo_barrios.py; do not edit. © OpenStreetMap contributors, ODbL.
"""

# ruff: noqa: E501

MONTEVIDEO_BARRIOS = {{
{rows}
}}
"""id → (name, lat, lng)."""
'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="compare, don't write")
    args = parser.parse_args()
    text = module(points(fetch()))
    if args.check:
        sys.exit(0 if OUT.read_text() == text else 1)
    OUT.write_text(text)
    print(f"wrote {len(BARRIOS)} barrios to {OUT}")


if __name__ == "__main__":
    main()
