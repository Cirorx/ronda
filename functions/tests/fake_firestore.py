"""An in-memory stand-in for the slice of google.cloud.firestore that proposals.py and rsvp.py
use, so the tests run without the emulator.

`transaction()` returns a stand-in the real `firestore.transactional` decorator can drive: it
buffers writes until `_commit`, like a batch, and drops them on `_rollback`."""

import copy
import itertools

from google.cloud.firestore import DELETE_FIELD


class FakeFirestore:
    def __init__(self, documents: dict[str, dict] | None = None) -> None:
        self.documents: dict[str, dict] = dict(documents or {})
        self._ids = itertools.count(1)

    def collection(self, path: str) -> "FakeCollection":
        return FakeCollection(self, path)

    def document(self, path: str) -> "FakeDocument":
        return FakeDocument(self, path)

    def batch(self) -> "FakeBatch":
        return FakeBatch(self)

    def transaction(self) -> "FakeTransaction":
        return FakeTransaction(self)

    def next_id(self) -> str:
        return f"auto{next(self._ids):03d}"


class FakeCollection:
    def __init__(self, db: FakeFirestore, path: str) -> None:
        self._db = db
        self._path = path

    def document(self, document_id: str | None = None) -> "FakeDocument":
        return FakeDocument(self._db, f"{self._path}/{document_id or self._db.next_id()}")

    def list_documents(self) -> list["FakeDocument"]:
        depth = self._path.count("/") + 2
        return [
            FakeDocument(self._db, path)
            for path in sorted(self._db.documents)
            if path.startswith(f"{self._path}/") and path.count("/") + 1 == depth
        ]

    def stream(self) -> list["FakeSnapshot"]:
        return [document.get() for document in self.list_documents()]


class FakeDocument:
    def __init__(self, db: FakeFirestore, path: str) -> None:
        self._db = db
        self.path = path
        self.id = path.rsplit("/", 1)[-1]

    def get(self, transaction: "FakeTransaction | None" = None) -> "FakeSnapshot":
        return FakeSnapshot(self.id, self._db.documents.get(self.path))

    def set(self, fields: dict, merge: bool = False) -> None:
        _write(self._db, ("set", self.path, fields, merge))

    def update(self, fields: dict) -> None:
        _write(self._db, ("update", self.path, fields, False))

    def delete(self) -> None:
        _write(self._db, ("delete", self.path, None, False))

    def collection(self, name: str) -> FakeCollection:
        return FakeCollection(self._db, f"{self.path}/{name}")


class FakeSnapshot:
    def __init__(self, document_id: str, fields: dict | None) -> None:
        self.id = document_id
        self.exists = fields is not None
        self._fields = fields

    def to_dict(self) -> dict | None:
        return None if self._fields is None else dict(self._fields)


class FakeBatch:
    def __init__(self, db: FakeFirestore) -> None:
        self._db = db
        self._writes: list = []

    def set(self, reference: FakeDocument, fields: dict, merge: bool = False) -> None:
        self._writes.append(("set", reference.path, fields, merge))

    def update(self, reference: FakeDocument, fields: dict) -> None:
        self._writes.append(("update", reference.path, fields, False))

    def delete(self, reference: FakeDocument) -> None:
        self._writes.append(("delete", reference.path, None, False))

    def commit(self) -> None:
        for write in self._writes:
            _write(self._db, write)


class FakeTransaction(FakeBatch):
    """What `google.cloud.firestore.transactional` calls on a transaction, and its writes."""

    _read_only = False
    _max_attempts = 1
    _id = b"fake-transaction"

    def _clean_up(self) -> None:
        pass

    def _begin(self, retry_id: bytes | None = None) -> None:
        self._writes = []

    def _commit(self) -> list:
        self.commit()
        return []

    def _rollback(self) -> None:
        self._writes = []


def _merge(current: dict, fields: dict) -> None:
    for key, value in fields.items():
        if isinstance(value, dict) and isinstance(current.get(key), dict):
            _merge(current[key], value)
        else:
            current[key] = value


def _write(db: FakeFirestore, write: tuple) -> None:
    kind, path, fields, merge = write
    fields = copy.deepcopy(fields, {id(DELETE_FIELD): DELETE_FIELD})
    if kind == "set" and merge:
        _merge(db.documents.setdefault(path, {}), fields)
    elif kind == "set":
        db.documents[path] = fields
    elif kind == "update":
        current = db.documents[path]
        for key, value in fields.items():
            if value is DELETE_FIELD:
                current.pop(key, None)
            else:
                current[key] = value
    else:
        db.documents.pop(path, None)
