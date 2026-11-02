# Evals

How Ronda measures the Meta models it runs, with invented demo data only. Each eval has an
offline path (recorded or hand-written model responses, so it runs in CI with no key) and a
`--live` path against the real API, whose keys come only from `scripts/smoke/_env.py` `key()`
(the environment, else the repo's `.env`; never printed).

- **`card/`** — the weekly card the organiser agent composes (#62, `functions/weekly_card.py`):
  for each demo ronda, whether the model's `compose_card` call fits the catalog schema, which
  gate each block passed or failed, how many blocks were dropped, whether the card fell back to
  the template, that two rondas in the same week get different cards, and the latency per card.
  Run `cd evals/card && uv run pytest` (recorded), or `uv run pytest --live` for the real
  models. Results land in `evals/card/RESULTS.md`.
