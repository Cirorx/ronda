# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["httpx>=0.28"]
# ///
"""Smoke test 6: Muse Image draws a "mate de más" poster, then redraws it with a SAM cutout as
the reference image, to judge whether the model's lettering is legible.

    uv run scripts/smoke/s6_image.py cutout.png out_dir
"""

import base64
import pathlib
import sys

import httpx
from _env import META_BASE, Timer, key

cutout, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
HEADERS = {"Authorization": f"Bearer {key('MODEL_API_KEY')}"}
PROMPT = (
    "Afiche de almacén de barrio en Montevideo, papel crema y tinta negra, estilo letrero "
    'pintado a mano. Texto grande y legible: "Hay un mate de más". Sin personas.'
)


def save(response: httpx.Response, name: str, seconds: float) -> None:
    if response.status_code != 200:
        print(name, "HTTP", response.status_code, response.text[:300])
        return
    body = response.json()
    path = out / f"{name}.png"
    path.write_bytes(base64.b64decode(body["data"][0]["b64_json"]))
    print(f"{name}: {seconds} s, usage {body.get('usage')} → {path}")


with Timer() as t:
    r = httpx.post(
        f"{META_BASE}/images/generations",
        headers=HEADERS,
        json={
            "model": "muse-image-1.0",
            "prompt": PROMPT,
            "size": "1024x1536",
            "output_format": "png",
        },
        timeout=180,
    )
save(r, "generation", t.s)

reference = "data:image/png;base64," + base64.b64encode(cutout.read_bytes()).decode()
with Timer() as t:
    r = httpx.post(
        f"{META_BASE}/images/edits",
        headers=HEADERS,
        json={
            "model": "muse-image-1.0",
            "prompt": PROMPT + " Usá este termo como único objeto del afiche.",
            "images": [{"image_url": reference}],
            "size": "1024x1536",
            "output_format": "png",
        },
        timeout=180,
    )
save(r, "edit", t.s)
