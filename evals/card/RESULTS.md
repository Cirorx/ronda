# Card eval results

Last run: 2026-11-01 20:57 local, model turns from hand-written stand-ins in `recorded/` (no key during the build; `--live` records the real thing). Three invented demo rondas, ISO week 2026-W45, the job run once at Monday 10:00 (`weekly_card.run_weekly_card`, counts {'rondas': 3, 'off': 0, 'held': 0, 'already': 0, 'agent': 2, 'template': 1}, wall clock 0.1 s).

| ronda | model | card | blocks kept | dropped | compose calls (invalid) | held: emoji / voseo / money / address | no fact / other | model turns | latency ms |
|---|---|---|---|---|---|---|---|---|---|
| mate | recorded | agent | rain, host, newcomer, despues | 0 | 1 (0) | 0 / 0 / 0 / 0 | 0 / 0 | 5 | 1 |
| truco | recorded | agent | rain, host, bench | 0 | 1 (0) | 0 / 0 / 0 / 0 | 0 / 0 | 4 | 2 |
| futbol5 | recorded | template (no quedó ningún aviso) | — | 2 | 1 (0) | 0 / 1 / 0 / 0 | 1 / 0 | 4 | 6 |

- Cards from the model: 2 of 3; distinct cards among them: 2.
- Schema validity: 0 invalid `compose_card` call(s) over 3.
- Blocks held by a gate: 1; dropped for a missing fact: 1.
- Every text kept passed `gates.check_words` again here (emoji, voseo, money, address), and no address reached a card.

Latency is the run's own clock from the start of the trace to the stored card, model turns included. Recorded runs measure only the code around the model.
