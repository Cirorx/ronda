"""The "Un mate de más" flyer: a host's photo of the group's things becomes a printable flyer.

`make_mate_flyer` is the whole of the `make_mate_flyer` callable except Firebase. The photo
arrives with every face already pixelated on the phone (`packages/face_blur`), at
`flyer_photos/{uid}/{photoId}.jpg`; it is re-saved here without EXIF as a backstop and deleted
once read, whatever happens. Then, side by side:

- SAM 3.1 looks for the termo, the mazo and the mates, one English noun phrase per request
  (Spanish ones found nothing in the smoke test, docs/MODELS.md), and each box-local mask is
  decoded with `meta-sam-parser` into a transparent cutout;
- Muse Image paints a background with no people and no text.

Every word and the QR are drawn here with Pillow and segno, so no copy comes from a model. The
flyer goes to `flyers/{uid}/{flyerId}.jpg` and `flyers/{flyerId}` records it, with the QR
pointing at `{LANDING_BASE}/f/{flyerId}`. Logs carry ids, counts and timings only.
"""

import asyncio
import base64
import io
import logging
import pathlib
import re
import time
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Protocol

import httpx
import segno
from meta_sam_parser import (
    SegmentationBoxRecord,
    SegmentationMaskRecord,
    decode_mask_to_raster,
    image_segmentation_format,
    parse_responses_stream,
)
from openai import AsyncOpenAI
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from voice_signup import BARRIOS, META_BASE, PRETEXTS

SAM_MODEL = "sam-3.1"
IMAGE_MODEL = "muse-image-1.0"

# The landing #43 serves for every flyer: one constant, so a custom domain is one edit.
LANDING_BASE = "https://ronda-uy.web.app"

PHOTO_PATH = re.compile(
    r"^flyer_photos/(?P<uid>[A-Za-z0-9_-]{1,128})/(?P<id>[A-Za-z0-9_-]{1,64})\.jpg$"
)
RONDA_ID = re.compile(r"^[A-Za-z0-9_-]{1,128}$")

# The phone sends at most 1600 px on the long side, well under 1 MB; Storage rules cap it at 3 MB.
MAX_PHOTO_BYTES = 3 * 1024 * 1024
MAX_PHOTO_SIDE = 4000
# What SAM sees, and so what the cutouts are cut from: big enough to print at flyer size.
SAM_SIDE = 1280

# What to cut out, the English phrases to try for each in order, and how many to keep.
OBJECTS: tuple[tuple[str, tuple[str, ...], int], ...] = (
    ("termo", ("thermos", "vacuum flask"), 1),
    ("mazo", ("deck of playing cards", "playing cards"), 1),
    ("mates", ("mate gourd", "gourd"), 3),
)
# A mask smaller than this share of the photo is a speck; larger, it's the whole table.
MIN_AREA, MAX_AREA = 0.002, 0.6

FLYER_SIZE = (1240, 1754)  # A-series portrait: A5 at about 210 dpi, A4 at 150
JPEG_QUALITY = 92

PAPER = (255, 254, 250)
INK = (24, 32, 47)
BIROME = (35, 65, 192)
MUTED = (90, 100, 119)
MARGEN = (200, 67, 60)

FONTS = pathlib.Path(__file__).resolve().parent / "fonts"
TITLE_FONT = FONTS / "YoungSerif-Regular.ttf"
BODY_FONT = FONTS / "AtkinsonHyperlegible-Regular.ttf"
BOLD_FONT = FONTS / "AtkinsonHyperlegible-Bold.ttf"

HEADLINE = "Hay un mate de más."
SUBHEAD = "Es tuyo."
BODY = "Cinco vecinos, a pocas cuadras, todas las semanas. Venís y listo; no hace falta traer nada."
MONEY = "Ronda nunca pide plata."
QR_CAPTION = "Escaneá y mirá las rondas cerca de acá"

DAYS = {
    "mon": "los lunes",
    "tue": "los martes",
    "wed": "los miércoles",
    "thu": "los jueves",
    "fri": "los viernes",
    "sat": "los sábados",
    "sun": "los domingos",
}
BANDS = {"morning": "de mañana", "afternoon": "de tarde", "evening": "de noche"}

# Muse Image read "rambla" as a Spanish boulevard (docs/MODELS.md): name the place in full.
SCENES = {
    "mate": "Montevideo's coastal promenade on the Río de la Plata: a low stone wall, a wide "
    "sidewalk and the water behind it.",
    "truco": "A wooden table in a small neighbourhood club, a window onto a quiet street.",
    "futbol5": "A small five-a-side football pitch behind a wire fence, trees around it.",
    "caminata": "A quiet tree-lined street of low houses with wide sidewalks.",
}
BACKGROUND_PROMPT = (
    "A calm, warm illustration for a neighbourhood poster in Ciudad de la Costa, Uruguay. "
    "{scene} Soft afternoon light, muted colours, a little paper texture. Keep the middle and the "
    "top third simple and uncluttered. No people, no text, no letters, no numbers, no signs, no "
    "logos."
)

log = logging.getLogger(__name__)


class FlyerError(Exception):
    """A flyer that can't be made; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


class ModelUnavailable(RuntimeError):
    """SAM 3.1 or Muse Image kept failing; the host can try again."""


@dataclass(frozen=True)
class Mask:
    """One object SAM found: its box in the photo it was sent, and a `width` × `height` raster
    of 0 and 1 stretched over that box."""

    left: int
    top: int
    right: int
    bottom: int
    width: int
    height: int
    raster: bytes
    confidence: float | None = None

    @property
    def area(self) -> int:
        """The box's area in the photo's pixels."""
        return max(0, self.right - self.left) * max(0, self.bottom - self.top)


class Segmenter(Protocol):
    """SAM 3.1: the masks of everything matching `concept` in a PNG."""

    async def segment(self, png: bytes, concept: str) -> list[Mask]: ...


class Painter(Protocol):
    """Muse Image: a PNG painted from `prompt`."""

    async def paint(self, prompt: str) -> bytes: ...


class MetaSam:
    """`Segmenter` on the Meta Model API: the Responses API streams SAM's boxes and base85
    masks, and `meta-sam-parser` decodes them (the request is scripts/smoke/s5_sam.py's)."""

    def __init__(self, client: Any) -> None:
        self._client = client  # an openai.AsyncOpenAI on META_BASE

    async def segment(self, png: bytes, concept: str) -> list[Mask]:
        data_url = "data:image/png;base64," + base64.b64encode(png).decode()
        try:
            events = await self._client.responses.create(
                model=SAM_MODEL,
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
            result = await parse_responses_stream(
                events, image_segmentation_format()
            ).final_result()
            box_confidence = {
                r.object_id: r.confidence
                for r in result.records
                if isinstance(r, SegmentationBoxRecord)
            }
            return [
                Mask(
                    left=int(r.bounds.left),
                    top=int(r.bounds.top),
                    right=int(r.bounds.right),
                    bottom=int(r.bounds.bottom),
                    width=r.mask.width,
                    height=r.mask.height,
                    raster=decode_mask_to_raster(r.mask),
                    confidence=r.confidence
                    if r.confidence is not None
                    else box_confidence.get(r.object_id),
                )
                for r in result.records
                if isinstance(r, SegmentationMaskRecord)
            ]
        except Exception as error:  # the SDK's and the parser's errors share no base
            raise ModelUnavailable(f"sam {type(error).__name__}") from error


class MuseImage:
    """`Painter` on the Meta Model API's `/images/generations` (scripts/smoke/s6_image.py's
    request): portrait, PNG, retried on 429 and 5xx."""

    def __init__(self, http: httpx.AsyncClient, api_key: str, *, backoff: float = 0.5) -> None:
        self._http, self._api_key, self._backoff = http, api_key, backoff

    async def paint(self, prompt: str, *, attempts: int = 3) -> bytes:
        for attempt in range(attempts):
            response = await self._http.post(
                f"{META_BASE}/images/generations",
                headers={"Authorization": f"Bearer {self._api_key}"},
                json={
                    "model": IMAGE_MODEL,
                    "prompt": prompt,
                    "size": "1024x1536",
                    "output_format": "png",
                },
                timeout=120,
            )
            if response.status_code == 200:
                try:
                    return base64.b64decode(response.json()["data"][0]["b64_json"])
                except (KeyError, IndexError, TypeError, ValueError) as error:
                    raise ModelUnavailable("muse image: no image") from error
            log.warning("muse image HTTP %s (attempt %s)", response.status_code, attempt + 1)
            if response.status_code != 429 and response.status_code < 500:
                break
            await asyncio.sleep(self._backoff * 2**attempt)
        raise ModelUnavailable(f"muse image HTTP {response.status_code}")


def may_make_flyer(db, ronda_id: str, ronda: dict, uid: str) -> bool:
    """Whether `uid` may make ronda `ronda_id`'s flyer: one of its hosts (`hosts.anfitrion`,
    `hosts.cola`) once it has any, and until then any active member, since `approve_proposal`
    writes rondas without hosts."""
    hosts = ronda.get("hosts") or {}
    host_uids = {hosts.get("anfitrion"), hosts.get("cola")} - {None}
    if host_uids:
        return uid in host_uids
    member = db.collection("rondas").document(ronda_id).collection("members").document(uid).get()
    return member.exists and (member.to_dict() or {}).get("state") == "active"


def read_photo(jpeg: bytes) -> Image.Image:
    """The photo as RGB pixels, with no EXIF left: `INVALID_ARGUMENT` for anything that isn't a
    reasonably sized image."""
    if len(jpeg) > MAX_PHOTO_BYTES:
        raise FlyerError("invalid-argument", "photo too large")
    try:
        with Image.open(io.BytesIO(jpeg)) as opened:
            if max(opened.size) > MAX_PHOTO_SIDE:
                raise FlyerError("invalid-argument", "photo too large")
            return opened.convert("RGB")
    except OSError as error:
        raise FlyerError("invalid-argument", "not an image") from error


def scaled(image: Image.Image, side: int) -> Image.Image:
    """`image` with its long side at most `side`."""
    factor = side / max(image.size)
    if factor >= 1:
        return image
    return image.resize((round(image.width * factor), round(image.height * factor)))


def usable(mask: Mask, photo_area: int) -> bool:
    """Whether a mask is an object: neither a speck nor most of the photo, and not empty."""
    return MIN_AREA <= mask.area / photo_area <= MAX_AREA and any(mask.raster)


def cutout(photo: Image.Image, mask: Mask) -> Image.Image:
    """The masked object alone on a transparent ground, cropped to its box (s5_sam.py's mask at
    its box offset)."""
    box = (
        max(0, mask.left),
        max(0, mask.top),
        min(photo.width, mask.right),
        min(photo.height, mask.bottom),
    )
    size = (box[2] - box[0], box[3] - box[1])
    alpha = Image.frombytes("L", (mask.width, mask.height), bytes(v * 255 for v in mask.raster))
    piece = photo.crop(box).convert("RGBA")
    piece.putalpha(alpha.resize(size))
    return piece


async def find_objects(png: bytes, photo_area: int, segmenter: Segmenter) -> list[Mask]:
    """The masks of the termo, the mazo and the mates, best first: each object tries its phrases
    in order until one finds something usable. Objects are looked for side by side."""

    async def find(phrases: tuple[str, ...], keep: int) -> list[Mask]:
        for phrase in phrases:
            masks = [m for m in await segmenter.segment(png, phrase) if usable(m, photo_area)]
            if masks:
                masks.sort(key=lambda m: (m.confidence or 0, m.area), reverse=True)
                return masks[:keep]
        return []

    found = await asyncio.gather(*(find(phrases, keep) for _, phrases, keep in OBJECTS))
    return [mask for masks in found for mask in masks]


def background_prompt(pretext: object) -> str:
    """Muse Image's prompt for the ronda's pretext, mate on the rambla by default."""
    scene = SCENES.get(pretext if isinstance(pretext, str) else "", SCENES["mate"])
    return BACKGROUND_PROMPT.format(scene=scene)


def ronda_line(ronda: dict) -> str:
    """The ronda in one line, from what it holds: `Mate en la rambla · los jueves de tarde ·
    Solymar Norte`."""
    pretext = PRETEXTS.get(ronda.get("pretext") or "")
    slot = ronda.get("slot") or {}
    when = " ".join(
        part for part in (DAYS.get(slot.get("day")), BANDS.get(slot.get("time"))) if part
    )
    parts = [
        pretext[0].upper() + pretext[1:] if pretext else None,
        when or None,
        BARRIOS.get(ronda.get("barrio") or ""),
    ]
    return " · ".join(part for part in parts if part)


def qr_image(url: str, side: int) -> Image.Image:
    """The QR for `url`, drawn in code (never by a model), `side` pixels square."""
    out = io.BytesIO()
    segno.make(url, error="m").save(out, kind="png", scale=10, border=2, dark=INK, light=PAPER)
    out.seek(0)
    with Image.open(out) as qr:
        return qr.convert("RGB").resize((side, side), Image.Resampling.NEAREST)


def _font(path: pathlib.Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size)


def _wrap(draw: ImageDraw.ImageDraw, text: str, font, width: int) -> list[str]:
    lines: list[str] = []
    for word in text.split():
        candidate = f"{lines[-1]} {word}" if lines else word
        if lines and draw.textlength(candidate, font=font) <= width:
            lines[-1] = candidate
        else:
            lines.append(word)
    return lines


def _text(draw, xy: tuple[int, int], text: str, font, fill, width: int, spacing: int) -> int:
    """Draws `text` wrapped to `width` from `xy`; returns the y below it."""
    x, y = xy
    for line in _wrap(draw, text, font, width):
        draw.text((x, y), line, font=font, fill=fill)
        y += font.size + spacing
    return y


def _cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    factor = max(size[0] / image.width, size[1] / image.height)
    resized = image.convert("RGB").resize(
        (round(image.width * factor), round(image.height * factor))
    )
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def compose(background: Image.Image, cutouts: list[Image.Image], line: str, url: str) -> bytes:
    """The flyer as a JPEG: the painted background, the headline and the ronda on paper at the
    top, the group's things in the middle, and the promise, the money line and the QR at the
    bottom."""
    width, height = FLYER_SIZE
    margin = 80
    flyer = _cover(background, FLYER_SIZE).convert("RGBA")
    paper = Image.new("RGBA", FLYER_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(paper)
    draw.rectangle((0, 0, width, 420), fill=(*PAPER, 236))
    draw.rectangle((0, 1270, width, height), fill=(*PAPER, 246))
    draw.rectangle((margin - 30, 0, margin - 26, 420), fill=(*MARGEN, 255))
    flyer = Image.alpha_composite(flyer, paper)

    draw = ImageDraw.Draw(flyer)
    y = _text(draw, (margin, 70), HEADLINE, _font(TITLE_FONT, 96), INK, width - 2 * margin, 8)
    y = _text(draw, (margin, y), SUBHEAD, _font(TITLE_FONT, 96), BIROME, width - 2 * margin, 8)
    _text(draw, (margin, y + 24), line, _font(BOLD_FONT, 40), MUTED, width - 2 * margin, 8)

    _place(flyer, cutouts, top=470, bottom=1220, left=margin, right=width - margin)

    qr_side = 340
    qr_left = width - margin - qr_side
    flyer.paste(qr_image(url, qr_side), (qr_left, 1305))
    _text(draw, (qr_left, 1305 + qr_side + 14), QR_CAPTION, _font(BODY_FONT, 28), INK, qr_side, 4)
    column = qr_left - margin - 48
    y = _text(draw, (margin, 1330), BODY, _font(BODY_FONT, 42), INK, column, 12)
    _text(draw, (margin, y + 28), MONEY, _font(BOLD_FONT, 42), INK, column, 12)

    out = io.BytesIO()
    flyer.convert("RGB").save(out, format="JPEG", quality=JPEG_QUALITY)
    return out.getvalue()


def _place(flyer: Image.Image, cutouts: list[Image.Image], **band: int) -> None:
    """Sets the cutouts side by side on the band's floor, each with a soft shadow. They come from
    one photo, so one scale for all keeps the termo taller than the mates: the largest that fits
    the tallest in the band's height and all of them in its width."""
    gap = 40
    room_w, room_h = band["right"] - band["left"], band["bottom"] - band["top"]
    total = sum(c.width for c in cutouts)
    factor = min(
        room_h / max(c.height for c in cutouts), (room_w - gap * (len(cutouts) - 1)) / total
    )
    x = band["left"] + round((room_w - total * factor - gap * (len(cutouts) - 1)) / 2)
    for piece in cutouts:
        size = (max(1, round(piece.width * factor)), max(1, round(piece.height * factor)))
        resized = piece.resize(size)
        y = band["bottom"] - size[1]
        shadow = Image.new("RGBA", size, (*INK, 0))
        shadow.putalpha(resized.getchannel("A").point(lambda a: a * 0.35))
        shadow = shadow.filter(ImageFilter.GaussianBlur(12))
        flyer.alpha_composite(shadow, (x + 14, min(y + 18, band["bottom"] - size[1])))
        flyer.alpha_composite(resized, (x, y))
        x += size[0] + gap


async def run_models(
    png: bytes, photo_area: int, prompt: str, segmenter: Segmenter, painter: Painter
) -> tuple[list[Mask], bytes]:
    """SAM's masks and Muse Image's background, side by side."""
    masks, background = await asyncio.gather(
        find_objects(png, photo_area, segmenter), painter.paint(prompt)
    )
    return masks, background


async def _with_meta_models(
    api_key: str, run: Callable[[Segmenter, Painter], Any]
) -> tuple[list[Mask], bytes]:
    """Runs `run` on the real SAM 3.1 and Muse Image clients, closed afterwards."""
    client = AsyncOpenAI(base_url=META_BASE, api_key=api_key, timeout=60, max_retries=2)
    async with httpx.AsyncClient() as http:
        try:
            return await run(MetaSam(client), MuseImage(http, api_key))
        finally:
            await client.close()


def photo_uid(path: object) -> str:
    """The uid in `flyer_photos/{uid}/{id}.jpg`, or `INVALID_ARGUMENT` for any other path."""
    if not isinstance(path, str) or not (match := PHOTO_PATH.match(path)):
        raise FlyerError("invalid-argument", "photoPath must be flyer_photos/{uid}/{id}.jpg")
    return match["uid"]


def make_mate_flyer(
    *,
    uid: str,
    data: object,
    db,
    bucket,
    api_key: str,
    now: datetime,
    segmenter: Segmenter | None = None,
    painter: Painter | None = None,
) -> dict:
    """The `make_mate_flyer` callable: checks the caller and the photo, makes the flyer, stores
    it and its `flyers/{id}` document, and returns `{flyerId, imagePath, landingUrl}`.

    Raises `FlyerError` with the callable's code. The photo is deleted once its path is known to
    be the caller's, whatever happens after.
    """
    data = data if isinstance(data, dict) else {}
    ronda_id, path = data.get("rondaId"), data.get("photoPath")
    if not isinstance(ronda_id, str) or not RONDA_ID.match(ronda_id):
        raise FlyerError("invalid-argument", "rondaId is required")
    if photo_uid(path) != uid:
        raise FlyerError("permission-denied", "not your photo")
    photo_blob = bucket.blob(path)
    started = time.perf_counter()
    try:
        snapshot = db.collection("rondas").document(ronda_id).get()
        if not snapshot.exists:
            raise FlyerError("not-found", "no such ronda")
        ronda = snapshot.to_dict() or {}
        if not may_make_flyer(db, ronda_id, ronda, uid):
            raise FlyerError("permission-denied", "only the ronda's hosts make its flyer")
        photo = scaled(read_photo(photo_blob.download_as_bytes()), SAM_SIDE)
        png = io.BytesIO()
        photo.save(png, format="PNG")
        area = photo.width * photo.height

        async def run(seg: Segmenter, paint: Painter) -> tuple[list[Mask], bytes]:
            return await run_models(
                png.getvalue(), area, background_prompt(ronda.get("pretext")), seg, paint
            )

        try:
            if segmenter is not None and painter is not None:
                masks, painted = asyncio.run(run(segmenter, painter))
            else:
                masks, painted = asyncio.run(_with_meta_models(api_key, run))
        except ModelUnavailable as error:
            raise FlyerError("unavailable", "try again in a moment") from error
        modelled = time.perf_counter()
        if not masks:
            raise FlyerError("failed-precondition", "no termo, mazo or mate in the photo")

        reference = db.collection("flyers").document()
        flyer_id = reference.id
        landing_url = f"{LANDING_BASE}/f/{flyer_id}"
        with Image.open(io.BytesIO(painted)) as background:
            jpeg = compose(
                background, [cutout(photo, m) for m in masks], ronda_line(ronda), landing_url
            )
        image_path = f"flyers/{uid}/{flyer_id}.jpg"
        bucket.blob(image_path).upload_from_string(jpeg, content_type="image/jpeg")
        reference.set(
            {
                "kind": "mate",
                "rondaId": ronda_id,
                "createdBy": uid,
                "createdAt": now,
                "imagePath": image_path,
            }
        )
        log.info(
            "make_mate_flyer %s: %d cutouts, models %d ms, total %d ms, %d bytes",
            flyer_id,
            len(masks),
            (modelled - started) * 1000,
            (time.perf_counter() - started) * 1000,
            len(jpeg),
        )
        return {"flyerId": flyer_id, "imagePath": image_path, "landingUrl": landing_url}
    finally:
        try:
            photo_blob.delete()
        except Exception as error:  # already gone; the 1-day lifecycle rule is the backstop
            log.warning("make_mate_flyer: photo delete failed (%s)", type(error).__name__)
