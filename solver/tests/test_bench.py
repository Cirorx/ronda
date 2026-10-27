import json
from pathlib import Path

import bench
from ronda_solver.demo import invented_problem

FIXTURE = Path(__file__).parent.parent / "fixtures" / "invented_demo_30.json"


def test_thirty_invented_neighbours_get_valid_groups_in_under_ten_seconds():
    row = bench.measure(30)

    assert row["valid"]
    assert row["total"] < 10


def test_the_bench_prints_a_row_per_size_and_passes(capsys):
    exit_code = bench.main(["--people", "30"])

    out = capsys.readouterr().out
    assert exit_code == 0
    assert "PASS" in out


def test_the_bench_fails_when_no_ronda_forms(capsys):
    assert bench.main(["--people", "3"]) == 1
    assert "FAIL" in capsys.readouterr().out


def test_the_committed_fixture_is_the_invented_thirty_and_says_so():
    fixture = json.loads(FIXTURE.read_text())

    assert fixture == invented_problem(30)
    assert fixture["_note"].startswith("Invented demo data")


def test_the_bench_prints_each_broken_hard_rule_and_fails(capsys, monkeypatch):
    broken = {"rule": "avoidPairApart", "rondaId": "x", "uids": ["demo-001", "demo-002"]}
    monkeypatch.setattr(bench, "check", lambda data, result: [broken])

    assert bench.main(["--people", "30"]) == 1
    assert "avoidPairApart" in capsys.readouterr().out
