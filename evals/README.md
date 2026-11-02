# Evals

How Ronda checks the Meta models it runs on, with numbers that are kept in the repo. Each
folder is one eval: what it measures, how to run it, where the results land. Every eval has an
**offline** path that replays recorded answers (so CI and a laptop without a key run it in
seconds) and a **live** path against the real API (`--live`), which rewrites the recorded
answers with `--record`.

Keys come from `.env` through `scripts/smoke/_env.py` `key()`, which never prints them. Only
invented notes and photos go in `fixtures/`: nothing a real person said or sent.

| Eval | Measures | Run | Results |
|---|---|---|---|
| [`voice/`](voice/) | Voice Transcribe realtime vs batch on the same note: time to first words, time to the final transcript after the person stops, and word error rate between the two and against the reference text (#64) | `uv run --with pytest --with websockets --with httpx pytest evals/voice` (add `--live`, `--record`) | [`voice/RESULTS.md`](voice/RESULTS.md) |
