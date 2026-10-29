"""The hourly audio sweeper: deletes the voice notes `extract` never deleted.

`extract` deletes each note once it is read (`voice_signup.read_voice_note`), which is the main
control. A note outlives that only when the app uploaded it and never called, or the delete
failed. Anything under `audio/` older than an hour is such a note, since no read takes that long
(`extract` times out at 120 s). The bucket's 1-day lifecycle rule stays the backstop.

`main.sweep_audio` runs it every hour. Logs carry counts only, never an object name (a name holds
the uid).
"""

import logging
from collections.abc import Iterable
from datetime import datetime, timedelta
from typing import Protocol

from google.api_core.exceptions import NotFound

PREFIX = "audio/"
MAX_AGE = timedelta(hours=1)

log = logging.getLogger(__name__)


class Note(Protocol):
    """The part of `google.cloud.storage.Blob` the sweeper uses."""

    time_created: datetime | None

    def delete(self) -> None: ...


class Bucket(Protocol):
    """The part of `google.cloud.storage.Bucket` the sweeper uses."""

    def list_blobs(self, *, prefix: str) -> Iterable[Note]: ...


def run_sweep_audio(bucket: Bucket, now: datetime) -> int:
    """Deletes every object under `audio/` created more than an hour before `now` (aware UTC).

    Returns how many it deleted. A note that is gone by the time it is deleted (`extract` got
    there first) is skipped, and so is one without a creation time.
    """
    cutoff = now - MAX_AGE
    found = deleted = 0
    for note in bucket.list_blobs(prefix=PREFIX):
        found += 1
        if note.time_created is None or note.time_created >= cutoff:
            continue
        try:
            note.delete()
        except NotFound:
            continue
        deleted += 1
    log.info("sweep_audio: deleted %d of %d notes under %s", deleted, found, PREFIX)
    return deleted
