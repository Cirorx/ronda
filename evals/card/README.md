# The weekly card the organiser composes

Does the organiser agent (`functions/weekly_card.py`, #62) put together a card that fits Ronda's
catalog and passes the gates, and what does a card cost? The job runs once over three invented
demo rondas in the same week (`rondas.py`: mate with a host, a newcomer and a después at a
home; truco with a host and someone on the bench; fútbol 5 with nothing set), with a rainy
stand-in forecast.

**Measures**

| Metric | What it is |
|---|---|
| schema validity | `compose_card` calls that fit the catalog (pydantic), over all calls |
| gate pass rate | per gate (emoji, voseo, money, address), blocks it let through over blocks proposed |
| blocks dropped | by a gate, or because their fact doesn't hold this week (no host, nobody new…) |
| fallback rate | cards stored as `template` over cards |
| different cards | two rondas in the same week get different cards from the model |
| latency, tokens, cost | per card: the model turns' time, tokens in and out, USD at the listed prices |

Every text kept is checked again against the gates, and no address may reach a card.
`fixtures/stand_ins/` holds hand-written answers that slip on purpose (tú instead of vos, a
host the ronda doesn't have) so the offline run shows the gates and the facts at work.

**Run**

```sh
cd evals/card
uv run pytest                    # offline: replays fixtures/ (no key, under a second)
uv run pytest --live             # the real models, nothing written
uv run pytest --live --record    # rewrites fixtures/recorded/ and RESULTS.md
```

Results land in [`RESULTS.md`](RESULTS.md): numbers and block kinds; the model's words are in
`fixtures/recorded/`, about invented people only.
