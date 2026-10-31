"""Smoke test 8: ¿Dónde queda?'s checks against the real Meta Model API, through the functions'
own code (functions/donde_queda.py): SAM 3.1 looks for people, number plates and house numbers
in a photo, `judge` says what would happen to it, and Muse Spark 1.3 reads a few answer lines.

    functions/venv/bin/python scripts/smoke/s8_donde_queda.py [photo.jpg ...]

Without a photo it draws an invented one: a wall with a door and a house-number plaque ("1234").
Use photos with no faces of anyone who didn't agree. Reads MODEL_API_KEY from the environment or
the repo's `.env` and never prints it. About seven SAM requests and three Spark calls a run.
"""

import asyncio
import io
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[2] / "functions"))
sys.path.insert(0, str(HERE.parent))

import donde_queda as d  # noqa: E402
import mate_flyer  # noqa: E402
from _env import META_BASE, Timer, key  # noqa: E402
from openai import AsyncOpenAI, OpenAI  # noqa: E402

LINES = [
    "la puerta verde de Gestido y Rivera",
    "la casa de Marta, Gestido 1234",
    "el mural de la escuela",
]


def invented_photo(*, number: bool = True) -> Image.Image:
    """A brick wall, a green door and, with `number`, a plaque reading 1234."""
    image = Image.new("RGB", (900, 700), (170, 90, 60))
    draw = ImageDraw.Draw(image)
    for y in range(0, 700, 24):
        draw.line((0, y, 900, y), fill=(200, 200, 190), width=3)
    draw.rectangle((330, 160, 570, 700), fill=(30, 120, 60))
    if number:
        fonts = HERE.parents[2] / "functions/fonts"
        font = ImageFont.truetype(str(fonts / "AtkinsonHyperlegible-Bold.ttf"), 80)
        draw.rectangle((620, 220, 820, 320), fill=(240, 240, 235), outline=(20, 20, 20), width=4)
        draw.text((640, 225), "1234", font=font, fill=(10, 10, 10))
    return image


async def segment(image: Image.Image, api_key: str) -> dict:
    png = io.BytesIO()
    image.save(png, format="PNG")
    client = AsyncOpenAI(base_url=META_BASE, api_key=api_key, timeout=60, max_retries=2)
    try:
        return await d._segment(png.getvalue(), mate_flyer.MetaSam(client))
    finally:
        await client.close()


def main() -> None:
    api_key = key("MODEL_API_KEY")
    photos = [(p, Image.open(p).convert("RGB")) for p in sys.argv[1:]] or [
        ("an invented wall with 1234", invented_photo()),
        ("the same wall, no number", invented_photo(number=False)),
    ]
    for name, image in photos:
        image = mate_flyer.scaled(image, d.PHOTO_SIDE)
        with Timer() as timer:
            found = asyncio.run(segment(image, api_key))
        counts = {concept: len(masks) for concept, masks in found.items()}
        verdict = d.judge(image, found)
        print(f"SAM 3.1 on {name}: {counts} in {timer.s} s")
        print(f"  refusal: {verdict.refusal}, would blur {len(verdict.blur)}")
    spark = d.SparkWords(OpenAI(base_url=META_BASE, api_key=api_key, timeout=30, max_retries=2))
    for line in LINES:
        gate = d.word_gates(line)
        with Timer() as timer:
            allowed = spark.allowed([line])
        print(f"Spark 1.3 «{line}»: gates {gate or 'ok'}, allowed {allowed} ({timer.s} s)")


if __name__ == "__main__":
    main()
