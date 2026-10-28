# Ronda solver

Forms rondas from sign-ups with OR-Tools CP-SAT (issue #23). Pure Python: JSON in, JSON out, no
Firebase imports. The `propose_groups` callable (#25) is a thin wrapper around `solve`.

```python
from ronda_solver import solve, check, score, explain

result = solve(data)  # proposals, unseated, rejected alternative and why
assert check(data, result) == []  # every hard rule kept
explain(data, result, edited)  # why any other grouping loses to the proposal
```

## Run

```sh
cd solver
uv sync                                    # Python 3.13 venv in solver/.venv
uv run pytest --cov                        # 100% coverage required
uv run ruff check . && uv run ruff format --check .
uv run python bench.py --people 30 200     # or, from the repo root: python solver/bench.py …
```

`bench.py` solves invented neighbours (`ronda_solver/demo.py`, seeded), runs the checker on the
groups and prints PASS or FAIL per size, with the rejected alternative's reason; it exits 1 if any size breaks a hard rule or forms no
ronda. `fixtures/invented_demo_30.json` is its 30-person input. All demo data is invented: no real
people; barrio names are real places in Ciudad de la Costa with approximate centroids.

## Input

```json
{
  "barrios": {"solymar-sur": {"lat": -34.833, "lng": -55.938}},
  "people": [
    {
      "uid": "demo-001",
      "ageBand": "60-69",
      "barrio": "solymar-sur",
      "pretexts": ["mate", "truco"],
      "slots": ["sat-afternoon", "sun-afternoon"],
      "eligibleSeatIds": ["solymar-sur_mate_sat-afternoon", "solymar-sur_truco_sat-afternoon"],
      "plusOneUid": "demo-002"
    }
  ],
  "avoidPairs": [["demo-003", "demo-004"]],
  "options": {"maxTimeInSeconds": 8, "alternativeTimeInSeconds": 2, "weights": {"trucoCrossAge": 0}}
}
```

- **No names, no needs.** The solver needs neither; the callable joins first names afterwards.
  Needs stay on the phone: `eligibleSeatIds` are the seats that passed them.
- **A seat id names its candidate ronda**, `{barrio}_{pretext}_{slot}` (the same key as
  `waitlists/{barrio_pretext_slot}`). Every seat of a candidate shares its facts, so the phone's
  filter works per candidate. Barrio, pretext and slot ids must not contain `_`
  (`ValueError`).
- `barrio` must be a key of `barrios`; uids are unique (otherwise `ValueError`).
- `plusOneUid` and `avoidPairs` naming someone not in `people` are ignored.
- `slots` and `pretexts` are opaque strings; `ageBand` is a decade (`18-29`, `30-39`, …, `80+`).
- `options` and every key in it are optional; `weights` overrides the table below by rule name
  (unknown names raise `ValueError`).

## Output

Shape only; the values are illustrative.

```json
{
  "status": "optimal",
  "proposals": [
    {
      "id": "solymar-sur_mate_sat-afternoon",
      "barrio": "solymar-sur", "pretext": "mate", "slot": "sat-afternoon",
      "members": [{"uid": "demo-001", "ageBand": "60-69", "barrio": "solymar-sur", "distanceBlocks": 0}],
      "checks": {"twoPerAgeBand": true, "sizeForPretext": true, "plusOneTogether": true,
                 "onePlusOnePair": true, "trucoCrossAge": true, "nearbyFirst": true}
    }
  ],
  "unseated": ["demo-007"],
  "rejectedAlternative": {
    "proposals": [], "unseated": [],
    "brokenRule": "twoPerAgeBand", "objectiveLoss": 75, "solveSeconds": 0.02,
    "reasons": [
      {"rule": "twoPerAgeBand", "hard": false, "units": 1, "loss": 120,
       "violations": [{"rondaId": "solymar-sur_mate_sat-afternoon", "uids": ["demo-004"],
                       "params": {"ageGroup": "60plus"}}]}
    ],
    "reason": "Alternativa B rechazada: hay una sola persona de 60 o más en una ronda."
  },
  "stats": {"objective": 5410, "buildSeconds": 0.004, "solveSeconds": 0.03,
            "candidates": 12, "seatVariables": 79}
}
```

- `status`: `optimal` or `feasible` (time ran out with a solution); `unknown` means no solution in
  time, with empty proposals and everyone unseated.
- `checks` are machine keys for the approval screen; its copy (en, es-419) lives in the app.
  `nearbyFirst` is true when every member is within 5 blocks (`near`).
- `rejectedAlternative` is alternative B, the next-best grouping: the best one that breaks some
  weighted soft rule more than the proposal or seats fewer (a cut on the proposal and on every
  grouping as good in every rule, so B always has a reason). `null` when nobody can be seated.
  `brokenRule` is its first reason's rule; `objectiveLoss` what it costs.
- `reasons` say why B loses, most decisive first (§ Why not the next best). `reason` is the first
  one as the es-419 sentence the admin reads; the app can render `reasons` itself in en.
- `check(data, result)` returns `[{"rule", "rondaId", "uids"}]`, one per broken hard rule, and is
  empty when the groups are valid. `score(data, result)` gives seated count, soft-rule units and
  objective for any result.

## Rules

Candidate rondas are barrio × pretext × slot, one each, so groups have no symmetry. Candidates
fewer people may join than their floor get no variables. Each rule is one named literal in
`ronda_solver/rules.py`, one method in `ronda_solver/model.py` and one pure check (`check.py` for
hard rules, `score.py` for soft) that returns its violations.

**Hard** (`HardRule`, checked by `check`):

| Literal | Rule |
|---|---|
| `eligibleSeat` | Only seats whose id the phone sent |
| `sameSlot` | The ronda's slot is one of the person's slots |
| `samePretext` | The ronda's pretext is one of the person's pretexts |
| `withinTenBlocks` | ≤ 10 blocks between barrio centroids (haversine; a block is 100 m) |
| `avoidPairApart` | A report-apart pair is never in the same ronda |
| `oneRondaEach` | Each person is in one ronda or in `unseated`, exactly once |
| `sizeBounds` | An open ronda has floor..cap members (below) |

**Size by pretext**: `futbol5` 8..10, target 10; `truco` 4..6, target 6; anything else 4..6,
target 5. A ronda at 3 is merged and one at 4 refilled, so 4 is the smallest the solver opens.

**Soft** (`SoftRule`): the objective is 1000 per seated neighbour minus weight × units. One
person's penalties add up to at most 730 (with one +1 pair each), so the solver never leaves
someone unseated to keep a soft rule; the soft rules choose among the ways to seat them.

| Literal | Unit | Weight |
|---|---|---|
| `twoPerAgeBand` | a member who is the only one of their age group in the ronda | 120 |
| `sizeForPretext` | a seat short of the pretext's target | 100 |
| `plusOneTogether` | a ronda holding one of a +1 pair without the other | 300 |
| `onePlusOnePair` | a +1 pair beyond the first in a ronda | 200 |
| `trucoCrossAge` | an under-30 in a truco ronda without an over-60 partner | 60 |
| `nearbyFirst` | a block walked to the ronda's barrio | 5 |

Age groups for the soft rules: `18-29` under 30; `30-39` to `50-59` one group; `60-69`, `70-79`
and `80+` are 60+ ("Hay al menos dos de 60 o más"). The truco rule may change with #9: edit
`TRUCO_*` in `rules.py`, or pass `"weights": {"trucoCrossAge": 0}` to switch it off.

## Why not the next best

`explain(data, result, alternative)` returns `{"reasons", "reason"}` for any grouping against
the proposal: the solver's B, or one the admin built by hand. `ronda_solver/explain.py`:

1. **Hard rules first.** A fresh CP-SAT model fixes the grouping's seats, gates each hard rule's
   constraints on one literal, solves with every literal as an assumption (one worker) and reads
   `sufficient_assumptions_for_infeasibility()`. Each rule in that set is a reason (`hard: true`,
   `loss: null`, `units` = its violations), and the soft rules are not compared. The set is
   *sufficient*, not complete: two broken rules may come back as one. The solver's own B keeps
   every hard rule, so this step only names something for a grouping built elsewhere.
2. **Otherwise, soft rules.** One pure check per rule (`score.py` soft, `check.py` hard) returns
   its violations, each with the units its weight prices. A soft rule is a reason when the
   alternative's units exceed the proposal's and its weight is above 0: `units` is the increase,
   `loss` = weight × units, and `violations` are the alternative's ones the proposal lacks.
   `fewerSeated` (loss 1000 a person) lists who lost their seat. Largest loss first.

Each violation is `{"rondaId", "uids", "params"}` (`rondaId` null for the whole grouping), so the
app can join first names. The solver renders the first reason (`ronda_solver/spanish.py`): the
copy is "Alternativa B rechazada: " + the phrase + ".".

| Reason | Phrase (es-419) | Varies with |
|---|---|---|
| `eligibleSeat` | pone a alguien en un lugar que no le sirve | |
| `sameSlot` | pone a alguien en un día y horario que no eligió | |
| `samePretext` | pone a alguien en una actividad que no eligió | |
| `withinTenBlocks` | pone a alguien a más de 10 cuadras de su barrio | |
| `avoidPairApart` | junta a dos personas que separaste | |
| `oneRondaEach` | pone a alguien en dos lugares a la vez · se olvida de alguien | `places` ≥ 2 · 0 |
| `sizeBounds` | abre una ronda de {pretext} con {members} y hacen falta {floor} · una ronda de {pretext} queda con {members} y el máximo es {cap} | below · above |
| `fewerSeated` | deja a {una persona · n personas} más sin lugar | `units` |
| `twoPerAgeBand` | hay una sola persona de {age group} en una ronda | `ageGroup` |
| `sizeForPretext` | una ronda de {pretext} queda con {members} y lo ideal son {target} | |
| `plusOneTogether` | separa a alguien de su invitado | |
| `onePlusOnePair` | pone a {pairs} personas con su invitado en la misma ronda | |
| `trucoCrossAge` | deja a {una persona · n personas} de menos de 30 sin compañero de 60 o más en el truco | `units` |
| `nearbyFirst` | hace caminar {una cuadra · n cuadras} más | `units` |

Age groups read "menos de 30", "30 a 59", "60 o más" (as the approval check "Hay al menos dos de
60 o más"; a band outside the groups reads as itself). Pretexts read as their id, except
`futbol5` → "fútbol 5". The phrases are plain and third person, except `avoidPairApart`, which
speaks to the admin who separated the pair. Parameters come from the first violation.

On the 30-person fixture B moves the truco ronda from Solymar Norte to Solymar Sur: "Alternativa
B rechazada: hace caminar 18 cuadras más." On small inputs the next best is often the same groups
a barrio over, so walking is the usual reason. Explaining adds under 1 ms for 30 people and about
4 ms for 200 (most of it the CP-SAT core).

## Limits

- One ronda per barrio × pretext × slot: twelve fútbol players in one barrio and slot seat ten.
- Season runs only: there is no input for existing rondas and their members, so refill (ronda at
  4) and merge (ronda at 3) are not built yet.
- The alternative is a second solve after the first: allow `maxTimeInSeconds` +
  `alternativeTimeInSeconds` (8 + 2 s by default) in the callable.
- CP-SAT uses every core. With 8 workers 200 invented people solve to optimality in 2–7 s; with
  1–4 workers the 8 s limit returns `feasible` (slightly fewer seated). 30 people take < 0.1 s.
