"""A whole voice sign-up on the Firestore and Storage emulators, with only Meta faked: what it
leaves behind holds no need and no voice note (`docs/ARCHITECTURE.md` § Thesis).

    cd functions
    firebase emulators:exec --only firestore,storage --project demo-ronda-voice \\
        "venv/bin/pytest tests/test_voice_signup_emulators.py"

The phone's side goes through the emulators' client APIs as the member, under
`firestore.rules` and `storage.rules`, in the shapes `packages/ronda_api` writes: the terms, the
note to `audio/{uid}/{id}.wav`, then on "Está bien, guardalo" the eligible seat ids its needs let
through and the profile read back from the note. The needs stay in this test, as they stay on
the phone. `extract` is the real callable over Admin clients on the same emulators, with Voice
Transcribe and Spark 1.3 faked. Every way a client could slip a need or a note into a document
is in `rules/users.test.js`.

Skipped without the emulators' hosts, and on any project that isn't a `demo-*` one; the functions
job in CI runs it again under `emulators:exec`, where skipping fails.
"""

import base64
import inspect
import json
import os
import re
import time
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import Any

import httpx
import openai
import pytest
from google.auth.credentials import AnonymousCredentials
from google.cloud import firestore, storage

import main
from tests.test_voice_signup import GRACIELA, spark_returning, transcript, wav

FIRESTORE = os.environ.get("FIRESTORE_EMULATOR_HOST")
# The Firebase API's host for the phone; the Admin client reads STORAGE_EMULATOR_HOST itself.
STORAGE = os.environ.get("FIREBASE_STORAGE_EMULATOR_HOST")
# Read before conftest's fixture points GCLOUD_PROJECT at the in-memory tests' project.
PROJECT = os.environ.get("GCLOUD_PROJECT", "")
BUCKET = f"{PROJECT}.appspot.com"
EMULATED = bool(
    FIRESTORE
    and STORAGE
    and os.environ.get("STORAGE_EMULATOR_HOST")
    and PROJECT.startswith("demo-")
)
WHY = "needs firebase emulators:exec --only firestore,storage on a demo-* project"

# CI sets RONDA_EMULATORS_REQUIRED, so a run that lost the emulators fails instead of skipping.
if os.environ.get("RONDA_EMULATORS_REQUIRED") and not EMULATED:
    pytest.fail(WHY, pytrace=False)
pytestmark = pytest.mark.skipif(not EMULATED, reason=WHY)

UID = "demo-voice-001"
NOTE_PATH = f"audio/{UID}/note-1.wav"
HEARD = "Hola, soy Graciela, tengo sesenta y pico, vivo en Solymar Norte."
TERMS = {"version": "2026-10-27", "acceptedAt": datetime(2026, 10, 29, 13, 0, tzinfo=UTC)}
PUBLISHED_AT = datetime(2026, 10, 29, 12, 0, tzinfo=UTC)

# `Need`'s value names in packages/needs_repository: the stored contract on the phone.
NEED_NAMES = ["walkALot", "climbStairs", "returnAfterDark", "noCar"]
# What this member marked in "lo que te complica ir".
NEEDS = {"climbStairs", "returnAfterDark"}


def seat(barrio: str, pretext: str, slot: str, **facts: Any) -> tuple[str, dict[str, Any]]:
    """An invented `seat_facts/{seatId}` as the server publishes it (`docs/ARCHITECTURE.md`)."""
    return f"{barrio}_{pretext}_{slot}", {
        "barrio": barrio,
        "pretext": pretext,
        "slot": slot,
        "blocksFrom": {"solymar-norte": 3, "solymar-sur": 6},
        "hasStairs": False,
        "endsAfterDark": False,
        "needsCar": False,
        "updatedAt": PUBLISHED_AT,
        **facts,
    }


SEAT_FACTS = dict(
    [
        seat("solymar-norte", "mate", "tue-afternoon"),
        seat("solymar-norte", "truco", "tue-afternoon", hasStairs=True),
        seat("solymar-norte", "mate", "tue-evening", endsAfterDark=True),
        seat("solymar-sur", "mate", "sat-morning"),
    ]
)


def eligible_seat_ids(needs: set[str], barrio: str) -> list[str]:
    """The phone's filter (`NeedsRepository.eligibleSeatIds`): each need rules out the seats it
    makes hard. A walk over ten blocks, or from a barrio the seat doesn't list, is far."""
    excludes = {
        "walkALot": lambda facts: facts["blocksFrom"].get(barrio, 11) > 10,
        "climbStairs": lambda facts: facts["hasStairs"],
        "returnAfterDark": lambda facts: facts["endsAfterDark"],
        "noCar": lambda facts: facts["needsCar"],
    }
    return [
        seat_id
        for seat_id, facts in SEAT_FACTS.items()
        if not any(excludes[need](facts) for need in needs)
    ]


def member_token(uid: str) -> str:
    """An unsigned ID token, which the emulators take as `uid` signed in (as rules-unit-testing
    makes them)."""
    now = int(time.time())

    def part(value: dict) -> str:
        return base64.urlsafe_b64encode(json.dumps(value).encode()).rstrip(b"=").decode()

    claims = {
        "iss": f"https://securetoken.google.com/{PROJECT}",
        "aud": PROJECT,
        "iat": now,
        "exp": now + 3600,
        "auth_time": now,
        "sub": uid,
        "user_id": uid,
        "firebase": {"sign_in_provider": "google.com", "identities": {}},
    }
    return f"{part({'alg': 'none', 'typ': 'JWT'})}.{part(claims)}."


def rest_value(value: Any) -> dict[str, Any]:
    """`value` as a Firestore REST `Value`, for the few types the phone writes."""
    if isinstance(value, str):
        return {"stringValue": value}
    if isinstance(value, datetime):
        return {"timestampValue": value.isoformat()}
    if isinstance(value, list):
        return {"arrayValue": {"values": [rest_value(item) for item in value]}}
    if isinstance(value, dict):
        return {"mapValue": {"fields": {k: rest_value(v) for k, v in value.items()}}}
    raise TypeError(type(value).__name__)


class Phone:
    """The app's writes for `UID`, through the emulators' client APIs, so the rules apply.

    `set` is `DocumentReference.set`: with `merge`, only the fields given are written, as
    `SetOptions(merge: true)` does for these top-level fields; the `server_time` fields get the
    request time, as `FieldValue.serverTimestamp()` does.
    """

    def __init__(self, http: httpx.Client) -> None:
        self._http = http
        self._token = member_token(UID)

    def set(
        self,
        path: str,
        fields: dict[str, Any],
        *,
        merge: bool = False,
        server_time: tuple[str, ...] = (),
    ) -> None:
        name = f"projects/{PROJECT}/databases/(default)/documents/{path}"
        write: dict[str, Any] = {
            "update": {"name": name, "fields": {k: rest_value(v) for k, v in fields.items()}},
            "updateTransforms": [
                {"fieldPath": field, "setToServerValue": "REQUEST_TIME"} for field in server_time
            ],
        }
        if merge:
            write["updateMask"] = {"fieldPaths": list(fields)}
        response = self._http.post(
            f"http://{FIRESTORE}/v1/projects/{PROJECT}/databases/(default)/documents:commit",
            headers={"Authorization": f"Bearer {self._token}"},
            json={"writes": [write]},
        )
        assert response.status_code == 200, f"the rules refused {path}: {response.text}"

    def upload_voice_note(self, path: str, audio: bytes) -> None:
        """`RondaApi.uploadVoiceNote`: the WAV with its content type."""
        response = self._http.post(
            f"http://{STORAGE}/v0/b/{BUCKET}/o",
            params={"name": path},
            headers={
                "Authorization": f"Firebase {self._token}",
                "Content-Type": "audio/wav",
                "X-Goog-Upload-Protocol": "raw",
            },
            content=audio,
        )
        assert response.status_code == 200, f"the rules refused {path}: {response.text}"


def every_document(db: firestore.Client) -> dict[str, dict[str, Any]]:
    """Every document in the project at any depth, read past the rules."""
    found: dict[str, dict[str, Any]] = {}

    def walk(collections) -> None:
        for collection in collections:
            for ref in collection.list_documents():
                snapshot = ref.get()
                if snapshot.exists:
                    found[ref.path] = snapshot.to_dict()
                walk(ref.collections())

    walk(db.collections())
    return found


def names_and_strings(value: Any) -> tuple[list[str], list[str]]:
    """Every field name at any depth, and every string value, in a document's fields."""
    names: list[str] = []
    strings: list[str] = []

    def walk(item: Any) -> None:
        if isinstance(item, dict):
            names.extend(item)
            for inner in item.values():
                walk(inner)
        elif isinstance(item, list):
            for inner in item:
                walk(inner)
        elif isinstance(item, str):
            strings.append(item)

    walk(value)
    return names, strings


@pytest.fixture
def db() -> firestore.Client:
    """An Admin Firestore client on the emulator, which sends it the `owner` token."""
    return firestore.Client(project=PROJECT, credentials=AnonymousCredentials())


@pytest.fixture
def bucket() -> storage.Bucket:
    """The Admin Storage bucket on the emulator (`STORAGE_EMULATOR_HOST`)."""
    client = storage.Client(project=PROJECT, credentials=AnonymousCredentials())
    return client.bucket(BUCKET)


@pytest.fixture
def signed_up(db, bucket, monkeypatch) -> dict[str, Any]:
    """Runs the sign-up on emptied emulators, with the seats published first; returns what
    `extract` answered and what Meta was sent."""
    with httpx.Client() as http:
        cleared = http.delete(
            f"http://{FIRESTORE}/emulator/v1/projects/{PROJECT}/databases/(default)/documents"
        )
        assert cleared.status_code == 200
        for blob in bucket.list_blobs():
            blob.delete()
        for seat_id, facts in SEAT_FACTS.items():
            db.document(f"seat_facts/{seat_id}").set(facts)

        phone = Phone(http)
        # A welcome door: the terms, before anything leaves the phone.
        phone.set(f"users/{UID}", {"terms": TERMS}, merge=True)
        # The recording, then the read-back's wait on extract.
        audio = wav(3)
        phone.upload_voice_note(NOTE_PATH, audio)
        assert bucket.blob(NOTE_PATH).exists()
        sent: list[bytes] = []
        fields = _extract(db, bucket, monkeypatch, sent)
        # "Está bien, guardalo": the needs filter the seats on the phone, then the ids, then
        # the profile as it was read back.
        phone.set(
            f"users/{UID}/private/eligible",
            {"seatIds": eligible_seat_ids(NEEDS, fields["barrio"])},
            server_time=("updatedAt",),
        )
        phone.set(f"users/{UID}", fields, merge=True, server_time=("createdAt",))
    return {"fields": fields, "audio": audio, "sent": sent}


def _extract(db, bucket, monkeypatch, sent: list[bytes]) -> dict[str, Any]:
    """Calls the real `extract` as `UID`; Voice Transcribe and Spark 1.3 answer from fakes."""

    def voice_transcribe(request: httpx.Request) -> httpx.Response:
        sent.append(request.read())
        return transcript(HEARD)

    client = httpx.Client
    with monkeypatch.context() as patch:
        patch.setattr(main, "_firestore", lambda: db)
        patch.setattr(main, "_bucket", lambda: bucket)
        patch.setenv("MODEL_API_KEY", "test-key")
        patch.setattr(
            httpx, "Client", lambda: client(transport=httpx.MockTransport(voice_transcribe))
        )
        patch.setattr(openai, "OpenAI", lambda **_: spark_returning(GRACIELA)[0])
        caller = SimpleNamespace(auth=SimpleNamespace(uid=UID, token={}), data={"path": NOTE_PATH})
        return inspect.unwrap(main.extract)(caller)


class TestVoiceSignUpOnTheEmulators:
    def test_extract_read_the_uploaded_note_and_answered_fields_only(self, signed_up):
        assert len(signed_up["sent"]) == 1
        assert signed_up["audio"] in signed_up["sent"][0]
        assert signed_up["fields"] == {
            "firstName": "Graciela",
            "ageBand": "60-69",
            "barrio": "solymar-norte",
            "pretexts": ["mate", "truco"],
            "slots": ["tue-afternoon"],
            "brings": ["termo"],
        }

    def test_firestore_holds_the_profile_the_eligible_ids_and_the_published_seats(
        self, signed_up, db
    ):
        documents = every_document(db)
        user = documents.pop(f"users/{UID}")
        eligible = documents.pop(f"users/{UID}/private/eligible")

        assert set(user) == {
            "terms",
            "firstName",
            "ageBand",
            "barrio",
            "slots",
            "pretexts",
            "brings",
            "createdAt",
        }
        assert set(eligible) == {"seatIds", "updatedAt"}
        # Stairs and the evening seat stayed out, and nothing says why.
        assert eligible["seatIds"] == [
            "solymar-norte_mate_tue-afternoon",
            "solymar-sur_mate_sat-morning",
        ]
        assert documents == {f"seat_facts/{k}": v for k, v in SEAT_FACTS.items()}

    def test_no_document_names_a_need_or_holds_a_voice_note(self, signed_up, db):
        need = re.compile("|".join(NEED_NAMES), re.IGNORECASE)
        for path, fields in every_document(db).items():
            names, strings = names_and_strings(fields)

            assert names, path
            assert [n for n in names if need.search(n)] == [], path
            assert [s for s in strings if need.search(s)] == [], path
            assert [s for s in strings if re.search(r"audio/|\.wav", s, re.IGNORECASE)] == [], path
            assert HEARD not in strings, path
            if not path.startswith("seat_facts/"):
                # The published seats name their own facts (`needsCar`); a member's never do.
                sensitive = re.compile(r"needs|mood|audio|voice|transcript", re.IGNORECASE)
                assert [n for n in names if sensitive.search(n)] == [], path

    def test_storage_holds_no_voice_note(self, signed_up, bucket):
        assert not bucket.blob(NOTE_PATH).exists()
        assert [blob.name for blob in bucket.list_blobs(prefix="audio/")] == []
