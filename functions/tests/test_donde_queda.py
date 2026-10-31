"""¿Dónde queda? over the Firestore and Storage stand-ins (donde_queda.py): the weekly job asks,
passes and reveals; the callables pass, post and guess. SAM 3.1 and Muse Spark 1.3 are scripted
stand-ins. The ronda is the rain check's: four invented members in El Pinar Sur who meet on
Thursdays (2026-11-05 is week 45), joined Mirta (demo-101), Jorge, Ana, Facu."""

import asyncio
import io
from datetime import timedelta
from types import SimpleNamespace

import pytest
from PIL import Image, ImageDraw

import donde_queda as d
import mate_flyer
from tests.fake_firestore import FakeFirestore
from tests.fake_storage import FakeBucket, StoredObject
from tests.organiser_fakes import RONDA, at, documents

FRI = at(30, 10, month=10)  # the day after the 10-29 meeting: week 45's game starts
W45 = "2026-W45"
W46 = "2026-W46"
CENTRE = {"lat": -34.8, "lng": -55.885}  # El Pinar Sur's centroid
NEAR = {"lat": -34.8005, "lng": -55.8852}
FAR_OFF = {"lat": -34.809, "lng": -55.885}
GAME = f"rondas/{RONDA}/donde_queda/{W45}"
VIEW = f"rondas/{RONDA}/views/donde_queda"
UPLOAD = "donde_queda_photos/demo-101/p1.jpg"


def player(db, uid: str) -> dict | None:
    return db.documents.get(f"rondas/{RONDA}/donde_queda_players/{uid}")


def jpeg(size=(400, 300)) -> bytes:
    image = Image.new("RGB", size, (170, 90, 60))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], 12):
        draw.line((0, y, size[0], y), fill=(200, 200, 190), width=2)
    out = io.BytesIO()
    image.save(out, format="JPEG")
    return out.getvalue()


class Sam:
    """SAM 3.1's stand-in: the masks scripted per phrase, and every phrase it was asked."""

    def __init__(self, found: dict | None = None, error: Exception | None = None):
        self.found, self.error, self.asked = found or {}, error, []

    async def segment(self, png: bytes, concept: str):
        self.asked.append(concept)
        if self.error:
            raise self.error
        return self.found.get(concept, [])


class Spark:
    def __init__(self, allowed=True, error=None):
        self._allowed, self._error, self.seen = allowed, error, []

    def allowed(self, texts):
        self.seen.append(texts)
        if self._error:
            raise self._error
        return self._allowed


def mask(left, top, right, bottom, raster=b"\x01\x01\x01\x01"):
    return mate_flyer.Mask(left, top, right, bottom, 2, 2, raster)


@pytest.fixture
def db() -> FakeFirestore:
    return FakeFirestore(documents())


@pytest.fixture
def bucket() -> FakeBucket:
    return FakeBucket({UPLOAD: StoredObject(jpeg(), None)})


def run(db, now, bucket=None):
    return d.run_donde_queda(db, now, bucket=bucket or FakeBucket())


def post(db, bucket, *, sam=None, spark=None, uid="demo-101", **fields):
    data = {
        "rondaId": RONDA,
        "week": W45,
        "photoPath": UPLOAD,
        "line": "la puerta verde de la esquina",
        "hint": "cerca de la feria",
        **NEAR,
        **fields,
    }
    return d.post_photo(
        uid=uid,
        data=data,
        db=db,
        bucket=bucket,
        api_key="test-key",
        now=FRI + timedelta(hours=2),
        segmenter=sam or Sam(),
        checker=spark or Spark(),
    )


def guess(db, uid, pin=NEAR, now=None):
    return d.guess(db, uid, {"rondaId": RONDA, "week": W45, **pin}, now or FRI + timedelta(hours=3))


class TestTheAsk:
    def test_the_first_week_asks_whoever_joined_first_and_tells_nobody_else(self, db):
        counts = run(db, FRI)

        assert counts == {"rondas": 1, "asked": 1, "passed": 0, "revealed": 0, "deleted": 0}
        game = db.documents[GAME]
        assert (game["status"], game["asked"], game["meeting"]) == (
            "asking",
            "demo-101",
            "2026-11-05",
        )
        assert player(db, "demo-101") == {
            "week": W45,
            "asked": True,
            "posted": False,
            "guessed": False,
            "updatedAt": FRI,
        }
        assert player(db, "demo-102") is None
        assert db.documents[VIEW]["current"] == {
            "week": W45,
            "status": "asking",
            "area": {**CENTRE, "zoom": 16},
            "closesOn": "2026-11-05",
        }
        assert db.documents[VIEW]["reveal"] is None
        assert db.documents[f"rondas/{RONDA}/private/donde_queda"] == {
            "lastStarter": "demo-101",
            "week": W45,
        }

    def test_running_again_changes_nothing(self, db):
        run(db, FRI)
        before = dict(db.documents[GAME])

        assert run(db, FRI + timedelta(hours=1))["asked"] == 0
        assert db.documents[GAME] == before

    def test_next_week_starts_one_after_this_weeks_first(self, db):
        run(db, FRI)
        run(db, at(6, 10))

        assert db.documents[f"rondas/{RONDA}/donde_queda/{W46}"]["asked"] == "demo-102"

    def test_two_days_without_a_photo_passes_the_turn_quietly(self, db):
        run(db, FRI)
        counts = run(db, FRI + timedelta(hours=48))

        assert counts["passed"] == 1
        game = db.documents[GAME]
        assert (game["asked"], game["passed"]) == ("demo-102", ["demo-101"])
        assert player(db, "demo-101")["asked"] is False
        assert player(db, "demo-102")["asked"] is True

    def test_too_few_to_play_has_no_game(self, db):
        for uid in ("demo-103", "demo-104"):
            db.documents[f"rondas/{RONDA}/members/{uid}"]["state"] = "left"

        assert run(db, FRI)["asked"] == 0
        assert GAME not in db.documents
        assert db.documents[VIEW]["current"] is None

    def test_rondas_that_dont_meet_or_have_no_map_are_left_alone(self, db):
        db.documents["rondas/ended"] = {"status": "ended", "barrio": "el-pinar-sur"}
        db.documents["rondas/nowhere"] = {"status": "active", "barrio": "atlantis"}
        db.documents["rondas/noslot"] = {"status": "active", "barrio": "el-pinar-sur"}

        assert run(db, FRI)["rondas"] == 1

    def test_the_bucket_is_the_admin_sdks_when_none_is_given(self, db, monkeypatch):
        bucket = FakeBucket()
        monkeypatch.setattr(d, "_default_bucket", lambda: bucket)
        run(db, FRI)
        db.documents[GAME].update(status="open", photoPath="donde_queda/x.jpg", pin=NEAR)
        bucket.objects["donde_queda/x.jpg"] = StoredObject(b"x", None)

        d.run_donde_queda(db, at(6, 10))

        assert bucket.objects == {}


class TestEstaSemanaNo:
    def test_passes_to_the_next_and_says_why_to_nobody(self, db):
        run(db, FRI)

        assert d.pass_turn(db, "demo-101", {"rondaId": RONDA, "week": W45}, FRI) == {
            "status": "passed"
        }
        assert db.documents[GAME]["asked"] == "demo-102"
        assert db.documents[VIEW]["current"]["status"] == "asking"

    def test_once_everyone_passed_the_week_has_no_game(self, db):
        run(db, FRI)
        for uid in ("demo-101", "demo-102", "demo-103", "demo-104"):
            d.pass_turn(db, uid, {"rondaId": RONDA, "week": W45}, FRI)

        assert db.documents[GAME]["status"] == "nobody"
        assert db.documents[VIEW]["current"]["status"] == "nobody"
        with pytest.raises(d.DondeQuedaError) as refused:
            d.pass_turn(db, "demo-101", {"rondaId": RONDA, "week": W45}, FRI)
        assert refused.value.code == "failed-precondition"

    def test_only_the_member_asked_can_pass(self, db):
        run(db, FRI)

        with pytest.raises(d.DondeQuedaError) as refused:
            d.pass_turn(db, "demo-103", {"rondaId": RONDA, "week": W45}, FRI)
        assert refused.value.code == "permission-denied"

    @pytest.mark.parametrize(
        "data",
        [None, {"week": W45}, {"rondaId": RONDA, "week": "45"}, {"rondaId": "a/b", "week": W45}],
    )
    def test_a_malformed_call_is_refused(self, db, data):
        with pytest.raises(d.DondeQuedaError) as refused:
            d.pass_turn(db, "demo-101", data, FRI)
        assert refused.value.code == "invalid-argument"

    def test_a_ronda_that_is_gone_is_not_found(self, db):
        run(db, FRI)
        del db.documents[f"rondas/{RONDA}"]

        with pytest.raises(d.DondeQuedaError) as refused:
            d.pass_turn(db, "demo-101", {"rondaId": RONDA, "week": W45}, FRI)
        assert refused.value.code == "not-found"


class TestThePhoto:
    def test_publishes_the_photo_with_passers_by_and_plates_blurred(self, db, bucket):
        run(db, FRI)
        sam = Sam({d.PERSON: [mask(10, 200, 40, 290)], d.PLATE: [mask(300, 260, 360, 280)]})
        spark = Spark()

        assert post(db, bucket, sam=sam, spark=spark) == {"status": "open"}

        assert UPLOAD not in bucket.objects
        published = bucket.objects[f"donde_queda/{RONDA}/{W45}.jpg"].data
        with Image.open(io.BytesIO(published)) as image:
            assert image.size == (400, 300)
            assert not image.getexif()
        assert sorted(sam.asked) == sorted(d.CONCEPTS)
        assert spark.seen == [["la puerta verde de la esquina", "cerca de la feria"]]
        game = db.documents[GAME]
        assert game["status"] == "open"
        assert game["photographer"] == "demo-101"
        assert game["pin"] == NEAR
        assert game["line"] == "la puerta verde de la esquina"
        assert player(db, "demo-101")["posted"] is True
        current = db.documents[VIEW]["current"]
        assert current["photoPath"] == f"donde_queda/{RONDA}/{W45}.jpg"
        assert current["hint"] == "cerca de la feria"
        assert "pin" not in current and "line" not in current

    def test_the_hint_is_optional(self, db, bucket):
        run(db, FRI)
        spark = Spark()

        post(db, bucket, spark=spark, hint="")

        assert spark.seen == [["la puerta verde de la esquina"]]
        assert db.documents[VIEW]["current"]["hint"] == ""

    @pytest.mark.parametrize(
        ("found", "reason"),
        [
            ({d.HOUSE_NUMBER: [mask(5, 5, 30, 20)]}, "houseNumber"),
            ({d.PERSON: [mask(50, 0, 350, 300)]}, "person"),
        ],
    )
    def test_a_refused_photo_says_why_and_publishes_nothing(self, db, bucket, found, reason):
        run(db, FRI)

        with pytest.raises(d.DondeQuedaError) as refused:
            post(db, bucket, sam=Sam(found))

        assert (refused.value.code, refused.value.reason) == ("failed-precondition", reason)
        assert bucket.objects == {}
        assert db.documents[GAME]["status"] == "asking"

    def test_an_empty_photo_is_refused_before_sam_sees_it(self, db):
        run(db, FRI)
        out = io.BytesIO()
        Image.new("RGB", (400, 300), (3, 3, 3)).save(out, format="JPEG")
        bucket = FakeBucket({UPLOAD: StoredObject(out.getvalue(), None)})
        sam = Sam()

        with pytest.raises(d.DondeQuedaError) as refused:
            post(db, bucket, sam=sam)

        assert refused.value.reason == "empty"
        assert sam.asked == []

    def test_an_empty_mask_is_nothing_found(self, db, bucket):
        run(db, FRI)

        post(db, bucket, sam=Sam({d.HOUSE_NUMBER: [mask(5, 5, 30, 20, raster=bytes(4))]}))

        assert db.documents[GAME]["status"] == "open"

    @pytest.mark.parametrize(
        "words",
        [{"line": "Gestido 1234"}, {"hint": "en lo de Mirta"}, {"line": "cuesta plata"}],
    )
    def test_words_that_fail_the_gates_never_reach_spark(self, db, bucket, words):
        run(db, FRI)
        spark = Spark()

        with pytest.raises(d.DondeQuedaError) as refused:
            post(db, bucket, spark=spark, **words)

        assert refused.value.reason == "words"
        assert spark.seen == []
        assert bucket.objects == {}

    def test_words_spark_holds_are_refused(self, db, bucket):
        run(db, FRI)

        with pytest.raises(d.DondeQuedaError) as refused:
            post(db, bucket, spark=Spark(allowed=False), line="la casa de la señora del perro")

        assert refused.value.reason == "words"

    @pytest.mark.parametrize("which", ["sam", "spark"])
    def test_a_model_that_fails_asks_to_try_again(self, db, bucket, which):
        run(db, FRI)
        down = mate_flyer.ModelUnavailable("down")
        models = {"sam": Sam(error=down)} if which == "sam" else {"spark": Spark(error=down)}

        with pytest.raises(d.DondeQuedaError) as refused:
            post(db, bucket, **models)

        assert refused.value.code == "unavailable"
        assert bucket.objects == {}

    def test_something_that_isnt_a_photo_is_refused(self, db):
        run(db, FRI)
        bucket = FakeBucket({UPLOAD: StoredObject(b"not a jpeg", None)})

        with pytest.raises(d.DondeQuedaError) as refused:
            post(db, bucket)

        assert refused.value.code == "invalid-argument"
        assert bucket.objects == {}

    @pytest.mark.parametrize(
        "fields",
        [
            {"line": ""},
            {"line": "x" * 81},
            {"line": "dos\nlíneas"},
            {"hint": 3},
            {"lat": -34.9},
            {"lat": "lejos"},
        ],
    )
    def test_a_malformed_post_is_refused_and_the_upload_deleted(self, db, bucket, fields):
        run(db, FRI)

        with pytest.raises(d.DondeQuedaError) as refused:
            post(db, bucket, **fields)

        assert refused.value.code == "invalid-argument"
        assert bucket.objects == {}

    def test_someone_elses_upload_is_not_touched(self, db, bucket):
        run(db, FRI)

        with pytest.raises(d.DondeQuedaError) as refused:
            post(db, bucket, uid="demo-102")

        assert refused.value.code == "permission-denied"
        assert UPLOAD in bucket.objects

    @pytest.mark.parametrize("path", [None, "flyer_photos/demo-101/p1.jpg", "donde_queda_photos/x"])
    def test_an_upload_path_of_another_shape_is_refused(self, db, bucket, path):
        with pytest.raises(d.DondeQuedaError) as refused:
            post(db, bucket, photoPath=path)
        assert refused.value.code == "invalid-argument"

    def test_a_member_not_asked_cannot_post_and_their_upload_is_deleted(self, db):
        run(db, FRI)
        upload = "donde_queda_photos/demo-103/p1.jpg"
        bucket = FakeBucket({upload: StoredObject(jpeg(), None)})

        with pytest.raises(d.DondeQuedaError) as refused:
            post(db, bucket, uid="demo-103", photoPath=upload)

        assert refused.value.code == "permission-denied"
        assert bucket.objects == {}

    def test_an_upload_already_gone_is_fine(self, db, bucket):
        run(db, FRI)
        del bucket.objects[UPLOAD]

        with pytest.raises(Exception):  # noqa: B017 - NotFound from the bucket
            post(db, bucket)

    def test_a_ronda_with_no_map_takes_no_pin(self, db, bucket):
        run(db, FRI)
        db.documents[f"rondas/{RONDA}"]["barrio"] = "atlantis"

        with pytest.raises(d.DondeQuedaError) as refused:
            post(db, bucket)
        assert refused.value.code == "invalid-argument"


class TestGuessesAndTheReveal:
    @pytest.fixture
    def posted(self, db, bucket):
        run(db, FRI)
        post(db, bucket)
        return bucket

    def test_each_member_drops_one_pin(self, db, posted):
        assert guess(db, "demo-102") == {"status": "guessed"}
        assert player(db, "demo-102")["guessed"] is True
        assert db.documents[GAME]["guesses"] == {"demo-102": NEAR}
        assert "guesses" not in db.documents[VIEW]["current"]

        with pytest.raises(d.DondeQuedaError) as again:
            guess(db, "demo-102", FAR_OFF)
        assert again.value.code == "already-exists"
        assert db.documents[GAME]["guesses"] == {"demo-102": NEAR}

    def test_the_photographer_doesnt_guess(self, db, posted):
        with pytest.raises(d.DondeQuedaError) as refused:
            guess(db, "demo-101")
        assert refused.value.code == "permission-denied"

    def test_only_members_guess(self, db, posted):
        db.documents[f"rondas/{RONDA}/members/demo-104"]["state"] = "left"

        for uid in ("demo-104", "stranger"):
            with pytest.raises(d.DondeQuedaError) as refused:
                guess(db, uid)
            assert refused.value.code == "permission-denied"

    def test_a_pin_off_the_map_is_refused(self, db, posted):
        with pytest.raises(d.DondeQuedaError) as refused:
            guess(db, "demo-102", {"lat": -34.9, "lng": -55.885})
        assert refused.value.code == "invalid-argument"

    def test_no_guess_before_the_photo(self, db):
        run(db, FRI)

        with pytest.raises(d.DondeQuedaError) as refused:
            guess(db, "demo-102")
        assert refused.value.code == "failed-precondition"

    def test_the_next_weeks_card_shows_the_line_and_the_counts_and_everything_else_goes(
        self, db, posted
    ):
        guess(db, "demo-102")
        guess(db, "demo-103", FAR_OFF)
        guess(db, "demo-104", CENTRE)

        counts = run(db, at(6, 10), posted)

        assert counts["revealed"] == 1
        reveal = {"week": W45, "line": "la puerta verde de la esquina", "close": 2, "guessed": 3}
        assert db.documents[VIEW]["reveal"] == reveal
        assert db.documents[GAME] == {
            "week": W45,
            "status": "revealed",
            "revealedFor": W46,
            "reveal": reveal,
            "revealedAt": at(6, 10),
        }
        assert posted.objects == {}
        for uid in ("demo-101", "demo-102", "demo-103", "demo-104"):
            assert (player(db, uid) or {}).get("week") != W45
        assert db.documents[VIEW]["current"]["week"] == W46

        run(db, at(6, 11), posted)
        assert db.documents[VIEW]["reveal"] == reveal

    def test_a_photo_already_gone_still_reveals(self, db, posted):
        posted.objects.clear()

        assert run(db, at(6, 10), posted)["revealed"] == 1

    def test_the_week_after_the_reveal_is_gone_for_good(self, db, posted):
        run(db, at(6, 10), posted)
        counts = run(db, at(13, 10), posted)

        assert GAME not in db.documents
        assert counts["deleted"] >= 1
        assert db.documents[VIEW]["reveal"] is None

    def test_a_week_nobody_posted_in_leaves_nothing_behind(self, db):
        run(db, FRI)

        run(db, at(6, 10))

        assert GAME not in db.documents
        assert player(db, "demo-101") is None
        assert db.documents[VIEW]["reveal"] is None


class TestSparkWords:
    def client(self, parsed=None, error=None):
        calls = []

        def parse(**kwargs):
            calls.append(kwargs)
            if error:
                raise error
            return SimpleNamespace(
                choices=[SimpleNamespace(message=SimpleNamespace(parsed=parsed))]
            )

        client = SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(parse=parse)))
        return client, calls

    def test_asks_spark_with_the_strict_schema_at_low_effort(self):
        client, calls = self.client(d.WordsVerdict(allowed=True, reason="ok"))

        assert d.SparkWords(client).allowed(["la puerta verde", "cerca de la feria"])
        assert calls[0]["model"] == "muse-spark-1.3"
        assert calls[0]["response_format"] is d.WordsVerdict
        assert calls[0]["reasoning_effort"] == "low"
        assert calls[0]["messages"][1]["content"] == "- la puerta verde\n- cerca de la feria"

    def test_holds_what_spark_holds_or_doesnt_call_ok(self):
        no, _ = self.client(d.WordsVerdict(allowed=False, reason="address"))
        odd, _ = self.client(d.WordsVerdict(allowed=True, reason="person"))

        assert not d.SparkWords(no).allowed(["x"])
        assert not d.SparkWords(odd).allowed(["x"])

    def test_no_answer_or_an_error_is_unavailable(self):
        empty, _ = self.client(None)
        broken, _ = self.client(error=RuntimeError("503"))

        for client in (empty, broken):
            with pytest.raises(mate_flyer.ModelUnavailable):
                d.SparkWords(client).allowed(["x"])


def test_segment_keeps_only_masks_with_something_in_them():
    sam = Sam({d.PERSON: [mask(0, 0, 1, 1), mask(0, 0, 1, 1, raster=bytes(4))]})

    found = asyncio.run(d._segment(b"png", sam))

    assert [len(found[c]) for c in d.CONCEPTS] == [1, 0, 0]
