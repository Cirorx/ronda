# Voice Transcribe: realtime vs batch

Does streaming the note to `wss://api.meta.ai/v1/asr/realtime` while the person talks
(`relay/`, `packages/live_transcript`) hear the same words as uploading the WAV to
`POST /v1/asr/transcribe` afterwards (`extract`), and how much earlier?

**Measures**, on one invented sign-up note (`make_note.sh`, the Mac's Spanish voice reading
`fixtures/reference.txt`, 16 kHz mono 16-bit, streamed at real time in 80 ms frames):

| Metric | What it is | Bar |
|---|---|---|
| time to first words | first `transcript` event after the first audio frame | ≤ 2.0 s |
| time to final | the `final: true` transcript after `endStream` (what the person waits once they stop) | ≤ 2.0 s |
| batch latency | the whole `POST /v1/asr/transcribe` round trip | reported |
| WER realtime vs batch | word error rate between the two transcripts | ≤ 0.10 |
| WER realtime vs reference, WER batch vs reference | against the text the voice read | ≤ 0.15 |

WER is plain word-level Levenshtein over lowercased words with punctuation stripped, no
dependency.

**Run**

```sh
# offline: replays fixtures/ (no key, seconds)
uv run --with pytest --with websockets --with httpx pytest evals/voice
# live: the real API, same note; --record rewrites the fixtures and RESULTS.md
evals/voice/make_note.sh                      # once, writes fixtures/note.wav (git-ignored)
uv run --with pytest --with websockets --with httpx pytest evals/voice --live --record
```

Results land in [`RESULTS.md`](RESULTS.md): numbers only, no transcripts.
