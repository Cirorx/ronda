"""Sends the functions' `log.info` lines to Cloud Logging with their severity.

Python's root logger starts at WARNING and Cloud Run reads plain stderr text without a level, so
until this runs every timing the jobs log at INFO is lost. Each record goes to stdout as one JSON
line with `severity` and `message`, which Cloud Logging reads as a structured entry.
"""

import json
import logging
import sys


class JsonLines(logging.Formatter):
    """One JSON object per record: its level as Cloud Logging's severity, the message, and the
    logger's name; a traceback, when there is one, rides inside the message."""

    def format(self, record: logging.LogRecord) -> str:
        message = record.getMessage()
        if record.exc_info:
            message = f"{message}\n{self.formatException(record.exc_info)}"
        return json.dumps(
            {"severity": record.levelname, "message": message, "logger": record.name},
            ensure_ascii=False,
        )


def setup(level: int = logging.INFO) -> None:
    """Sends records at `level` and above to stdout as JSON lines. Running it again replaces the
    handler it added, so a reload never doubles every line."""
    root = logging.getLogger()
    for handler in [h for h in root.handlers if isinstance(h.formatter, JsonLines)]:
        root.removeHandler(handler)
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonLines())
    root.addHandler(handler)
    root.setLevel(level)
