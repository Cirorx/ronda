"""Renders a structured reason as the es-419 sentence the admin reads (copy in solver/README.md)."""

from ronda_solver.rules import (
    FEWER_SEATED,
    FROM_30_TO_59,
    MAX_WALK_BLOCKS,
    SIXTY_PLUS,
    TRUCO_OLD,
    TRUCO_YOUNG,
    UNDER_30,
    HardRule,
    SoftRule,
)

PREFIX = "Alternativa B rechazada: "

AGE_GROUPS_ES = {UNDER_30: "menos de 30", FROM_30_TO_59: "30 a 59", SIXTY_PLUS: "60 o más"}
"""A band outside rules.AGE_GROUPS is its own group and reads as the band itself."""


PRETEXTS_ES = {"futbol5": "fútbol 5"}
"""Every other pretext id reads as itself (mate, truco, caminata)."""


def _pretext(pretext: str) -> str:
    return PRETEXTS_ES.get(pretext, pretext)


def _people(n: int) -> str:
    return "una persona" if n == 1 else f"{n} personas"


def _first(reason: dict) -> dict:
    return reason["violations"][0]["params"]


def _age(group: str) -> str:
    return AGE_GROUPS_ES.get(group, group)


def _two_per_age_band(reason: dict) -> str:
    return f"hay una sola persona de {_age(_first(reason)['ageGroup'])} en una ronda"


def _size_for_pretext(reason: dict) -> str:
    params = _first(reason)
    return (
        f"una ronda de {_pretext(params['pretext'])} queda con {params['members']} "
        f"y lo ideal son {params['target']}"
    )


def _one_plus_one_pair(reason: dict) -> str:
    return f"pone a {_first(reason)['pairs']} personas con su invitado en la misma ronda"


def _truco_cross_age(reason: dict) -> str:
    return (
        f"deja a {_people(reason['units'])} de {_age(TRUCO_YOUNG)} sin compañero de "
        f"{_age(TRUCO_OLD)} en el truco"
    )


def _nearby_first(reason: dict) -> str:
    blocks = "una cuadra" if reason["units"] == 1 else f"{reason['units']} cuadras"
    return f"hace caminar {blocks} más"


def _fewer_seated(reason: dict) -> str:
    return f"deja a {_people(reason['units'])} más sin lugar"


def _fixed(sentence: str):
    return lambda reason: sentence


def _size_bounds(reason: dict) -> str:
    params = _first(reason)
    pretext = _pretext(params["pretext"])
    if params["members"] < params["floor"]:
        return (
            f"abre una ronda de {pretext} con {params['members']} y hacen falta {params['floor']}"
        )
    return f"una ronda de {pretext} queda con {params['members']} y el máximo es {params['cap']}"


def _one_ronda_each(reason: dict) -> str:
    if _first(reason)["places"] == 0:
        return "se olvida de alguien"
    return "pone a alguien en dos lugares a la vez"


PHRASES = {
    HardRule.ELIGIBLE_SEAT: _fixed("pone a alguien en un lugar que no le sirve"),
    HardRule.SAME_SLOT: _fixed("pone a alguien en un día y horario que no eligió"),
    HardRule.SAME_PRETEXT: _fixed("pone a alguien en una actividad que no eligió"),
    HardRule.WITHIN_TEN_BLOCKS: _fixed(
        f"pone a alguien a más de {MAX_WALK_BLOCKS} cuadras de su barrio"
    ),
    HardRule.AVOID_PAIR_APART: _fixed("junta a dos personas que separaste"),
    HardRule.ONE_RONDA_EACH: _one_ronda_each,
    HardRule.SIZE_BOUNDS: _size_bounds,
    FEWER_SEATED: _fewer_seated,
    SoftRule.TWO_PER_AGE_BAND: _two_per_age_band,
    SoftRule.SIZE_FOR_PRETEXT: _size_for_pretext,
    SoftRule.PLUS_ONE_TOGETHER: _fixed("separa a alguien de su invitado"),
    SoftRule.ONE_PLUS_ONE_PAIR: _one_plus_one_pair,
    SoftRule.TRUCO_CROSS_AGE: _truco_cross_age,
    SoftRule.NEARBY_FIRST: _nearby_first,
}


def in_spanish(reason: dict) -> str:
    return f"{PREFIX}{PHRASES[reason['rule']](reason)}."
