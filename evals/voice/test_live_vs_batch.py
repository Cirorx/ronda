"""Voice Transcribe realtime vs batch on the same invented note (README.md).

Offline, it replays `fixtures/realtime_events.json` and `fixtures/batch.json`; `--live` runs
both against the real API, and `--record` rewrites the fixtures and `RESULTS.md`.
"""

import asyncio
import json
import re
from datetime import UTC, datetime
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
FIXTURES = HERE / "fixtures"
RESULTS = HERE / "RESULTS.md"

FIRST_WORDS_MS = 2000
FINAL_MS = 2000
WER_VS_BATCH = 0.10
WER_VS_REFERENCE = 0.15


def words_of(text: str) -> list[str]:
    return re.findall(r"[\w']+", text.lower())


def wer(hypothesis: str, reference: str) -> float:
    """Word error rate: word-level Levenshtein distance over the reference's length."""
    h, r = words_of(hypothesis), words_of(reference)
    if not r:
        return 0.0 if not h else 1.0
    previous = list(range(len(h) + 1))
    for i, ref_word in enumerate(r, 1):
        current = [i]
        for j, hyp_word in enumerate(h, 1):
            current.append(
                min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + (ref_word != hyp_word),
                )
            )
        previous = current
    return previous[-1] / len(r)


def metrics(realtime: dict, batch: dict, reference: str) -> dict:
    transcripts = [e for e in realtime["events"] if e.get("type") == "transcript"]
    first = next((e for e in transcripts if e.get("transcript")), None)
    final = next((e for e in transcripts if e.get("final")), None)
    assert first and final, "no transcript events in the realtime session"
    return {
        "noteSeconds": round(realtime["note"]["seconds"], 1),
        "firstWordsMs": first["atMs"] - realtime["audioStartMs"],
        "finalMs": final["atMs"] - realtime["endStreamMs"],
        "partials": len(transcripts),
        "batchLatencyMs": batch["latencyMs"],
        "werRealtimeVsBatch": round(wer(final["transcript"], batch["transcript"]), 3),
        "werRealtimeVsReference": round(wer(final["transcript"], reference), 3),
        "werBatchVsReference": round(wer(batch["transcript"], reference), 3),
    }


@pytest.fixture(scope="session")
def reference() -> str:
    return (FIXTURES / "reference.txt").read_text().strip()


@pytest.fixture(scope="session")
def runs(live: bool, record: bool) -> tuple[dict, dict]:
    if not live:
        return (
            json.loads((FIXTURES / "realtime_events.json").read_text()),
            json.loads((FIXTURES / "batch.json").read_text()),
        )
    from meta_voice import stream_realtime, transcribe_batch

    note = FIXTURES / "note.wav"
    assert note.exists(), "run evals/voice/make_note.sh first"
    realtime = asyncio.run(stream_realtime(note))
    batch = transcribe_batch(note)
    if record:
        (FIXTURES / "realtime_events.json").write_text(
            json.dumps(realtime, indent=1, ensure_ascii=False) + "\n"
        )
        (FIXTURES / "batch.json").write_text(
            json.dumps(batch, indent=1, ensure_ascii=False) + "\n"
        )
    return realtime, batch


@pytest.fixture(scope="session")
def measured(runs, reference, live, record) -> dict:
    found = metrics(*runs, reference)
    if live and record:
        write_results(found)
    return found


def write_results(m: dict) -> None:
    today = datetime.now(UTC).date().isoformat()
    RESULTS.write_text(
        f"""# Results: Voice Transcribe realtime vs batch

Measured {today} from Uruguay on the invented {m["noteSeconds"]} s note
(`make_note.sh`), streamed at real time. Numbers only; see README.md for the bars.

| Metric | Value | Bar |
|---|---|---|
| time to first words | {m["firstWordsMs"]} ms | ≤ {FIRST_WORDS_MS} ms |
| time to final after endStream | {m["finalMs"]} ms | ≤ {FINAL_MS} ms |
| partial transcripts received | {m["partials"]} | — |
| batch latency (upload + transcript) | {m["batchLatencyMs"]} ms | — |
| WER realtime vs batch | {m["werRealtimeVsBatch"]} | ≤ {WER_VS_BATCH} |
| WER realtime vs reference | {m["werRealtimeVsReference"]} | ≤ {WER_VS_REFERENCE} |
| WER batch vs reference | {m["werBatchVsReference"]} | ≤ {WER_VS_REFERENCE} |

What it means for the app: with live transcription the person waits about the "time to
final" once they stop talking, plus Spark's ~2 s for the fields; without it, the upload plus
the batch latency, then Spark.
"""
    )


class TestWer:
    def test_is_zero_for_the_same_words_whatever_the_punctuation(self):
        assert wer("Hola, soy Marta.", "hola soy marta") == 0

    def test_counts_substitutions_insertions_and_deletions(self):
        assert wer("hola soy marta", "hola soy marta y vivo") == pytest.approx(2 / 5)
        assert wer("hola soy juan", "hola soy marta") == pytest.approx(1 / 3)
        assert wer("hola soy marta hoy", "hola soy marta") == pytest.approx(1 / 3)

    def test_an_empty_reference(self):
        assert wer("", "") == 0
        assert wer("algo", "") == 1


class TestRealtime:
    def test_first_words_come_within_two_seconds(self, measured):
        assert 0 < measured["firstWordsMs"] <= FIRST_WORDS_MS

    def test_the_final_transcript_comes_within_two_seconds_of_stopping(self, measured):
        assert 0 <= measured["finalMs"] <= FINAL_MS

    def test_partials_grow_while_the_person_talks(self, measured):
        assert measured["partials"] >= 5


class TestAgreement:
    def test_realtime_hears_what_batch_hears(self, measured):
        assert measured["werRealtimeVsBatch"] <= WER_VS_BATCH

    def test_both_hear_the_reference(self, measured):
        assert measured["werRealtimeVsReference"] <= WER_VS_REFERENCE
        assert measured["werBatchVsReference"] <= WER_VS_REFERENCE
