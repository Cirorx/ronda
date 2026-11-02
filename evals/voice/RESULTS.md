# Results: Voice Transcribe realtime vs batch

Measured 2026-11-02 from Uruguay on the invented 10.5 s note
(`make_note.sh`), streamed at real time. Numbers only; see README.md for the bars.

| Metric | Value | Bar |
|---|---|---|
| time to first words | 726 ms | ≤ 2000 ms |
| time to final after endStream | 250 ms | ≤ 2000 ms |
| partial transcripts received | 24 | — |
| batch latency (upload + transcript) | 3168 ms | — |
| WER realtime vs batch | 0.057 | ≤ 0.1 |
| WER realtime vs reference | 0.0 | ≤ 0.15 |
| WER batch vs reference | 0.061 | ≤ 0.15 |

What it means for the app: with live transcription the person waits about the "time to
final" once they stop talking, plus Spark's ~2 s for the fields; without it, the upload plus
the batch latency, then Spark.
