# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["openai>=1.100", "pydantic>=2.11"]
# ///
"""Smoke test 2: Spark 1.3 fills a strict `Signup` schema from a typed rioplatense transcript.

uv run scripts/smoke/s2_structured.py
"""

from enum import StrEnum

from _env import META_BASE, Timer, key
from openai import OpenAI
from pydantic import BaseModel, ConfigDict


class AgeBand(StrEnum):
    UNDER_30 = "under_30"
    FROM_30_TO_49 = "30_49"
    FROM_50_TO_64 = "50_64"
    OVER_65 = "65_plus"


class Slot(StrEnum):
    WEEKDAY_MORNING = "weekday_morning"
    WEEKDAY_EVENING = "weekday_evening"
    SATURDAY = "saturday"
    SUNDAY = "sunday"


class Signup(BaseModel):
    model_config = ConfigDict(extra="forbid")
    first_name: str
    age_band: AgeBand
    barrio: str
    pretexts: list[str]
    slots: list[Slot]
    brings: list[str]


# Invented for the demo: no real person.
TRANSCRIPT = (
    "Hola, soy Mirta, tengo sesenta y dos, vivo en Solymar cerca de la rambla. Me gustaría "
    "el mate en la rambla o un truco. Puedo los sábados de mañana y los martes a la tardecita. "
    "Llevo bizcochos y un termo."
)

client = OpenAI(base_url=META_BASE, api_key=key("MODEL_API_KEY"))
with Timer() as t:
    r = client.beta.chat.completions.parse(
        model="muse-spark-1.3",
        response_format=Signup,
        messages=[
            {"role": "system", "content": "Extraé los datos de la inscripción. No inventes."},
            {"role": "user", "content": TRANSCRIPT},
        ],
    )
print(f"{t.s} s", r.usage)
print(r.choices[0].message.parsed)
