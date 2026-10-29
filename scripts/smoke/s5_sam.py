# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["openai>=1.100", "meta-sam-parser>=0.1", "Pillow>=11"]
# ///
"""Smoke test 5: SAM 3.1 finds objects by a short noun phrase, in Spanish and English, and one
mask becomes a transparent PNG cutout.

    uv run scripts/smoke/s5_sam.py photo.png out_dir [concept ...]

Use a photo with no faces. Defaults compare "termo" with "thermos" and "mate" with "mate gourd".
"""

import asyncio
import base64
import pathlib
import sys

from _env import META_BASE, Timer, key
from meta_sam_parser import (
    SegmentationMaskRecord,
    decode_mask_to_raster,
    image_segmentation_format,
    parse_responses_stream,
)
from openai import AsyncOpenAI
from PIL import Image

photo, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
concepts = sys.argv[3:] or ["termo", "thermos", "mate", "mate gourd"]
out.mkdir(parents=True, exist_ok=True)
client = AsyncOpenAI(base_url=META_BASE, api_key=key("MODEL_API_KEY"))
data_url = "data:image/png;base64," + base64.b64encode(photo.read_bytes()).decode()


async def segment(concept: str):
    events = await client.responses.create(
        model="sam-3.1",
        stream=True,
        input=[
            {
                "role": "user",
                "content": [
                    {"type": "input_text", "text": concept},
                    {"type": "input_image", "image_url": data_url},
                ],
            }
        ],
    )
    result = await parse_responses_stream(events, image_segmentation_format()).final_result()
    return [r for r in result.records if isinstance(r, SegmentationMaskRecord)]


def cutout(record: SegmentationMaskRecord, name: str) -> pathlib.Path:
    """Paints the mask at its bounds onto an alpha channel and crops to them."""
    image = Image.open(photo).convert("RGBA")
    m, b = record.mask, record.bounds
    box = tuple(int(v) for v in (b.left, b.top, b.right, b.bottom))
    raster = decode_mask_to_raster(m)
    small = Image.frombytes("L", (m.width, m.height), bytes(v * 255 for v in raster))
    alpha = Image.new("L", image.size, 0)
    alpha.paste(small.resize((box[2] - box[0], box[3] - box[1])), box[:2])
    image.putalpha(alpha)
    path = out / f"{name.replace(' ', '_')}.png"
    image.crop(box).save(path)
    return path


async def main():
    for concept in concepts:
        with Timer() as t:
            masks = await segment(concept)
        best = max(masks, key=lambda r: r.confidence or 0, default=None)
        conf = [round(r.confidence or 0, 2) for r in masks]
        line = f"{concept!r:14} {t.s:5} s  {len(masks)} mask(s) {conf}"
        if best:
            line += f"  bounds {best.bounds}  → {cutout(best, concept)}"
        print(line)


asyncio.run(main())
