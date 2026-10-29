"""An in-memory stand-in for the slice of a google.cloud.storage bucket that `extract` and the
audio sweeper use: open an object by name, list by prefix, download and delete, with the
`NotFound` the real client raises for a missing object."""

from dataclasses import dataclass
from datetime import datetime

from google.api_core.exceptions import NotFound


@dataclass
class StoredObject:
    data: bytes
    time_created: datetime | None


class FakeBucket:
    def __init__(self, objects: dict[str, StoredObject] | None = None) -> None:
        self.objects: dict[str, StoredObject] = dict(objects or {})

    def blob(self, name: str) -> "FakeBlob":
        return FakeBlob(self, name)

    def list_blobs(self, *, prefix: str = "") -> list["FakeBlob"]:
        return [FakeBlob(self, name) for name in sorted(self.objects) if name.startswith(prefix)]


class FakeBlob:
    def __init__(self, bucket: FakeBucket, name: str) -> None:
        self._bucket = bucket
        self.name = name
        stored = bucket.objects.get(name)
        self.time_created = stored.time_created if stored else None

    def download_as_bytes(self) -> bytes:
        return self._stored().data

    def delete(self) -> None:
        self._stored()
        del self._bucket.objects[self.name]

    def _stored(self) -> StoredObject:
        if self.name not in self._bucket.objects:
            raise NotFound(f"no object {self.name}")
        return self._bucket.objects[self.name]
