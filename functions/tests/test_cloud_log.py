"""cloud_log.py: the functions' log lines as Cloud Logging reads them."""

import json
import logging

import pytest

import cloud_log


@pytest.fixture(autouse=True)
def restore_root():
    root = logging.getLogger()
    handlers, level = list(root.handlers), root.level
    yield
    root.handlers[:] = handlers
    root.setLevel(level)


def test_an_info_line_reaches_stdout_with_its_severity(capsys):
    cloud_log.setup()

    logging.getLogger("weekly_card").info("weekly_card: %s", {"agent": 1})

    line = json.loads(capsys.readouterr().out)
    assert line == {
        "severity": "INFO",
        "message": "weekly_card: {'agent': 1}",
        "logger": "weekly_card",
    }


def test_a_traceback_rides_in_the_message(capsys):
    cloud_log.setup()

    try:
        raise ValueError("sin lugar")
    except ValueError:
        logging.getLogger("bench").exception("falló el banco")

    line = json.loads(capsys.readouterr().out)
    assert line["severity"] == "ERROR"
    assert line["message"].startswith("falló el banco\nTraceback")
    assert "ValueError: sin lugar" in line["message"]


def test_setting_up_twice_writes_each_line_once(capsys):
    cloud_log.setup()
    cloud_log.setup()

    logging.getLogger("rain").warning("una vez")

    assert len(capsys.readouterr().out.splitlines()) == 1


def test_lines_below_the_level_are_left_out(capsys):
    cloud_log.setup(logging.WARNING)

    logging.getLogger("rain").info("no sale")

    assert capsys.readouterr().out == ""
