# Results: the weekly card the organiser composes

Measured 2026-11-02 from Uruguay with `--live --record` on the real models (Muse Spark Open on Baseten, Spark 1.3 as fallback, `reasoning_effort: low`). Three invented demo rondas in ISO week 2026-W45, the job run once (`weekly_card.run_weekly_card`, forced, counts {'rondas': 3, 'off': 0, 'held': 0, 'already': 0, 'agent': 2, 'template': 1}, wall clock 23.1 s). Numbers and the cards' kinds only; the texts are in `fixtures/recorded/`.

| ronda | model | card | blocks kept | dropped | compose calls (invalid) | held: emoji / voseo / money / address | no fact / other | turns | latency | tokens in / out | cost |
|---|---|---|---|---|---|---|---|---|---|---|---|
| mate | meta-models/muse-spark-open-1026 | agent | rain, host, newcomer, despues | 0 | 1 (0) | 0 / 0 / 0 / 0 | 0 / 0 | 4 | 7.5 s | 9822 / 907 | $0.0161 |
| truco | meta-models/muse-spark-open-1026 | agent | rain, host, bench | 0 | 1 (0) | 0 / 0 / 0 / 0 | 0 / 0 | 4 | 7.7 s | 9765 / 1270 | $0.0176 |
| futbol5 | meta-models/muse-spark-open-1026 | template (no quedó ningún aviso) | — | 0 | 1 (0) | 0 / 0 / 0 / 0 | 0 / 0 | 4 | 7.9 s | 9306 / 1293 | $0.0171 |

- Schema validity: 3/3 (100%) `compose_card` calls fitted the catalog.
- Gate pass rate per gate, over the 7 blocks proposed: emoji 7/7 (100%), voseo 7/7 (100%), money 7/7 (100%), address 7/7 (100%).
- Blocks dropped: 0 (0 for a fact that didn't hold).
- Fallback to the template: 1/3 (33%) of the cards.
- Cards from the model: 2 of 3, 2 distinct.
- Per card: mean latency 7.7 s, mean cost $0.0170.

Latency is the model turns' own time, tools excluded (the forecast is a stand-in here). Cost uses $1.25 in / $4.25 out per million tokens for both models (reasoning tokens are billed as output).
