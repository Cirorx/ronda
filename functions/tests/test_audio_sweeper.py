"""The hourly audio sweeper over an in-memory bucket: what a run deletes and what it leaves."""

import logging
from datetime import UTC, datetime, timedelta

import audio_sweeper
from tests.fake_storage import FakeBucket, StoredObject

NOW = datetime(2026, 10, 29, 15, 0, tzinfo=UTC)


def note(minutes_old: float | None) -> StoredObject:
    created = None if minutes_old is None else NOW - timedelta(minutes=minutes_old)
    return StoredObject(b"RIFF", created)


def sweep(bucket: FakeBucket) -> int:
    return audio_sweeper.run_sweep_audio(bucket, NOW)


class TestRunSweepAudio:
    def test_deletes_every_note_older_than_an_hour(self):
        bucket = FakeBucket(
            {
                "audio/demo-001/never-read.wav": note(61),
                "audio/demo-002/delete-failed.wav": note(60 * 23),
            }
        )

        assert sweep(bucket) == 2
        assert bucket.objects == {}

    def test_leaves_a_note_extract_may_still_be_reading(self):
        bucket = FakeBucket(
            {
                "audio/demo-001/just-uploaded.wav": note(2),
                "audio/demo-001/an-hour-old.wav": note(60),
                "audio/demo-002/older.wav": note(61),
            }
        )

        assert sweep(bucket) == 1
        assert set(bucket.objects) == {
            "audio/demo-001/just-uploaded.wav",
            "audio/demo-001/an-hour-old.wav",
        }

    def test_touches_nothing_outside_audio(self):
        bucket = FakeBucket(
            {
                "photos/demo-001/blurred.jpg": note(600),
                "audio-archive/x.wav": note(600),
            }
        )

        assert sweep(bucket) == 0
        assert len(bucket.objects) == 2

    def test_skips_a_note_extract_deleted_first(self):
        bucket = FakeBucket(
            {"audio/demo-001/raced.wav": note(90), "audio/demo-002/x.wav": note(90)}
        )
        listed = bucket.list_blobs(prefix="audio/")
        del bucket.objects["audio/demo-001/raced.wav"]
        bucket.list_blobs = lambda *, prefix: listed

        assert sweep(bucket) == 1
        assert bucket.objects == {}

    def test_skips_a_note_without_a_creation_time(self):
        bucket = FakeBucket({"audio/demo-001/unknown.wav": note(None)})

        assert sweep(bucket) == 0
        assert len(bucket.objects) == 1

    def test_logs_counts_and_never_a_note_name(self, caplog):
        bucket = FakeBucket({"audio/demo-001/a.wav": note(61), "audio/demo-001/b.wav": note(1)})

        with caplog.at_level(logging.INFO, logger=audio_sweeper.__name__):
            sweep(bucket)

        assert "deleted 1 of 2" in caplog.text
        assert "demo-001" not in caplog.text
