"""An in-memory stand-in for the slice of google.cloud.firestore that proposals.py uses, so the
tests run without the emulator. test_emulator.py runs the same calls against the real one."""

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

    def get(self) -> "FakeSnapshot":
        return FakeSnapshot(self.id, self._db.documents.get(self.path))

    def set(self, fields: dict) -> None:
        self._db.documents[self.path] = dict(fields)

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

    def set(self, reference: FakeDocument, fields: dict) -> None:
        self._writes.append(("set", reference.path, fields))

    def update(self, reference: FakeDocument, fields: dict) -> None:
        self._writes.append(("update", reference.path, fields))

    def delete(self, reference: FakeDocument) -> None:
        self._writes.append(("delete", reference.path, None))

    def commit(self) -> None:
        for kind, path, fields in self._writes:
            if kind == "set":
                self._db.documents[path] = dict(fields)
            elif kind == "update":
                current = self._db.documents[path]
                for key, value in fields.items():
                    if value is DELETE_FIELD:
                        current.pop(key, None)
                    else:
                        current[key] = value
            else:
                self._db.documents.pop(path, None)
