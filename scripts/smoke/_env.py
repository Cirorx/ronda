"""Keys for the smoke tests, from the environment or the repo's `.env`.

Never prints a value: a missing key exits with its name only. The repo is public and the
Baseten key can't be rotated, so nothing here logs headers, keys or the file's contents.
"""

import os
import pathlib
import sys
import time

ENV_FILE = pathlib.Path(__file__).resolve().parents[2] / ".env"
META_BASE = "https://api.meta.ai/v1"
BASETEN_BASE = "https://inference.baseten.co/v1"


def key(name: str) -> str:
    """Returns `name` from the environment, else from `.env`; exits if it is in neither."""
    if value := os.environ.get(name):
        return value
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            k, sep, v = line.partition("=")
            name_matches = k.strip().removeprefix("export ").strip() == name
            if sep and name_matches and (v := v.strip().strip("'\"")):
                return v
    sys.exit(f"{name} missing (set it in .env)")


class Timer:
    """`with Timer() as t: ...` then `t.s` is the elapsed seconds, rounded to 0.1."""

    def __enter__(self):
        self._start = time.perf_counter()
        return self

    def __exit__(self, *_):
        self.s = round(time.perf_counter() - self._start, 1)
