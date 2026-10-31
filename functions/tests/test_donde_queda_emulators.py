"""A whole round of ¿Dónde queda? on the Firestore and Storage emulators with three members,
only SAM 3.1 and Muse Spark 1.3 faked: the turn, a photo with a face already pixelated on the
phone and someone passing by, two guesses, and the reveal on the next week's card, after which
the photo, the pin and every guess are gone. A house number is refused on the way.

    cd functions
    firebase emulators:exec --only firestore,storage --project demo-ronda-donde-queda \\
        "venv/bin/pytest tests/test_donde_queda_emulators.py"

The phone's side (the upload, reading the view, its own card and the photo) goes through the
emulators' client APIs as each member, under `firestore.rules` and `storage.rules`; the job and
the callables run on Admin clients against the same emulators. Every person is invented.

Skipped without the emulators' hosts, and on any project that isn't a `demo-*` one; CI runs it
under `emulators:exec`, where skipping fails.
"""

import io
import urllib.parse
from datetime import UTC, datetime

import httpx
import pytest
from google.auth.credentials import AnonymousCredentials
from google.cloud import firestore, storage
from PIL import Image, ImageDraw

import donde_queda as d
import mate_flyer
from tests.test_voice_signup_emulators import EMULATED, FIRESTORE, PROJECT, STORAGE, WHY
from tests.test_voice_signup_emulators import member_token as token

pytestmark = pytest.mark.skipif(not EMULATED, reason=WHY)

BUCKET = f"{PROJECT}.appspot.com"
RONDA = "demo-dq-ronda"
PEOPLE = ["demo-dq-1", "demo-dq-2", "demo-dq-3"]  # joined in this order
WEEK = "2026-W45"
FRIDAY = datetime(2026, 10, 30, 13, 0, tzinfo=UTC)  # 10:00 in Montevideo, after a Thursday
NEXT_FRIDAY = datetime(2026, 11, 6, 13, 0, tzinfo=UTC)
PIN = {"lat": -34.8, "lng": -55.885}  # El Pinar Sur's centroid


def phone_photo() -> bytes:
    """What `face_blur` uploads: a wall and a green door, with a face already pixelated into
    cells, as a JPEG with no EXIF."""
    image = Image.new("RGB", (400, 300), (170, 90, 60))
    draw = ImageDraw.Draw(image)
    for y in range(0, 300, 12):
        draw.line((0, y, 400, y), fill=(200, 200, 190), width=2)
    draw.rectangle((150, 60, 250, 290), fill=(30, 120, 60))
    for x in range(300, 340, 8):  # the face, already eight cells across on the phone
        for y in range(40, 80, 8):
            draw.rectangle((x, y, x + 7, y + 7), fill=(200 - x % 40, 160, 140))
    out = io.BytesIO()
    image.save(out, format="JPEG")
    return out.getvalue()


class Sam:
    def __init__(self, found):
        self.found = found

    async def segment(self, png, concept):
        return self.found.get(concept, [])


class Spark:
    def allowed(self, texts):
        return True


class Phone:
    """One member's app: the emulators' client APIs with their token, so the rules apply."""

    def __init__(self, http: httpx.Client, uid: str) -> None:
        self._http, self.uid = http, uid
        self._token = token(uid)

    def upload(self, path: str, jpeg: bytes) -> None:
        response = self._http.post(
            f"http://{STORAGE}/v0/b/{BUCKET}/o",
            params={"name": path},
            headers={
                "Authorization": f"Firebase {self._token}",
                "Content-Type": "image/jpeg",
                "X-Goog-Upload-Protocol": "raw",
            },
            content=jpeg,
        )
        assert response.status_code == 200, response.text

    def photo(self, path: str) -> int:
        """The status of reading the photo at `path`."""
        encoded = urllib.parse.quote(path, safe="")
        return self._http.get(
            f"http://{STORAGE}/v0/b/{BUCKET}/o/{encoded}",
            params={"alt": "media"},
            headers={"Authorization": f"Firebase {self._token}"},
        ).status_code

    def read(self, path: str) -> int:
        """The status of reading the document at `path`."""
        return self._http.get(
            f"http://{FIRESTORE}/v1/projects/{PROJECT}/databases/(default)/documents/{path}",
            headers={"Authorization": f"Bearer {self._token}"},
        ).status_code


@pytest.fixture
def db() -> firestore.Client:
    return firestore.Client(project=PROJECT, credentials=AnonymousCredentials())


@pytest.fixture
def bucket() -> storage.Bucket:
    return storage.Client(project=PROJECT, credentials=AnonymousCredentials()).bucket(BUCKET)


@pytest.fixture
def http():
    with httpx.Client() as client:
        cleared = client.delete(
            f"http://{FIRESTORE}/emulator/v1/projects/{PROJECT}/databases/(default)/documents"
        )
        assert cleared.status_code == 200
        yield client


@pytest.fixture
def ronda(db, bucket, http) -> None:
    for blob in bucket.list_blobs():
        blob.delete()
    db.document(f"rondas/{RONDA}").set(
        {
            "pretext": "mate",
            "barrio": "el-pinar-sur",
            "slot": {"day": "thu", "time": "afternoon"},
            "status": "active",
        }
    )
    for minute, uid in enumerate(PEOPLE):
        db.document(f"rondas/{RONDA}/members/{uid}").set(
            {"state": "active", "joinedAt": datetime(2026, 10, 1, 12, minute, tzinfo=UTC)}
        )


def post(db, bucket, phone: Phone, found: dict, name: str) -> None:
    path = f"donde_queda_photos/{phone.uid}/{name}.jpg"
    phone.upload(path, phone_photo())
    d.post_photo(
        uid=phone.uid,
        data={
            "rondaId": RONDA,
            "week": WEEK,
            "photoPath": path,
            "line": "la puerta verde de la esquina",
            "hint": "cerca de la feria",
            **PIN,
        },
        db=db,
        bucket=bucket,
        api_key="",
        now=FRIDAY,
        segmenter=Sam(found),
        checker=Spark(),
    )


def test_a_whole_round_with_three_members(db, bucket, http, ronda):
    photographer, near, far = (Phone(http, uid) for uid in PEOPLE)
    view = f"rondas/{RONDA}/views/donde_queda"

    # The job asks whoever joined first; only they see it on their card.
    d.run_donde_queda(db, FRIDAY, bucket=bucket)
    assert db.document(f"rondas/{RONDA}/donde_queda_players/{PEOPLE[0]}").get().get("asked")
    assert photographer.read(f"rondas/{RONDA}/donde_queda_players/{PEOPLE[0]}") == 200
    assert near.read(f"rondas/{RONDA}/donde_queda_players/{PEOPLE[0]}") == 403
    assert near.read(f"rondas/{RONDA}/donde_queda/{WEEK}") == 403

    # A house number is refused, and nothing stays behind.
    with pytest.raises(d.DondeQuedaError) as refused:
        post(
            db,
            bucket,
            photographer,
            {d.HOUSE_NUMBER: [mate_flyer.Mask(5, 5, 40, 20, 1, 1, b"\x01")]},
            "p0",
        )
    assert refused.value.reason == "houseNumber"
    assert list(bucket.list_blobs()) == []

    # The photo: the face came pixelated from the phone; SAM finds someone passing by.
    passer_by = mate_flyer.Mask(20, 200, 50, 290, 1, 1, b"\x01")
    post(db, bucket, photographer, {d.PERSON: [passer_by]}, "p1")
    published = f"donde_queda/{RONDA}/{WEEK}.jpg"
    assert [blob.name for blob in bucket.list_blobs()] == [published]
    with Image.open(io.BytesIO(bucket.blob(published).download_as_bytes())) as image:
        assert not image.getexif()
    for phone in (photographer, near, far):
        assert phone.photo(published) == 200
        assert phone.read(view) == 200
    assert Phone(http, "demo-dq-stranger").photo(published) == 403
    assert Phone(http, "demo-dq-stranger").read(view) == 403

    # Two guesses: one on the door, one a kilometre off.
    d.guess(db, near.uid, {"rondaId": RONDA, "week": WEEK, **PIN}, FRIDAY)
    d.guess(db, far.uid, {"rondaId": RONDA, "week": WEEK, "lat": -34.809, "lng": -55.885}, FRIDAY)

    # The next week's card shows the reveal; the photo, the pin and the guesses are gone.
    d.run_donde_queda(db, NEXT_FRIDAY, bucket=bucket)
    shown = db.document(view).get().to_dict()
    assert shown["reveal"] == {
        "week": WEEK,
        "line": "la puerta verde de la esquina",
        "close": 1,
        "guessed": 2,
    }
    assert shown["current"]["week"] == "2026-W46"
    assert list(bucket.list_blobs()) == []
    assert photographer.photo(published) in (403, 404)
    game = db.document(f"rondas/{RONDA}/donde_queda/{WEEK}").get().to_dict()
    assert set(game) == {"week", "status", "revealedFor", "reveal", "revealedAt"}
    players = db.collection(f"rondas/{RONDA}/donde_queda_players").stream()
    assert all(p.to_dict()["week"] != WEEK for p in players)
