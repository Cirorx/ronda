# Ronda solver

Forms rondas from sign-ups with OR-Tools CP-SAT (issue #23). Pure Python: JSON in, JSON out, no
Firebase imports. The `propose_groups` callable (#25) is a thin wrapper around `solve`.

```python
from ronda_solver import solve, check, score

result = solve(data)  # proposals, unseated, rejected alternative
assert check(data, result) == []  # every hard rule kept
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
groups and prints PASS or FAIL per size; it exits 1 if any size breaks a hard rule or forms no
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
    "brokenRule": "twoPerAgeBand", "objectiveLoss": 75, "solveSeconds": 0.02
  },
  "stats": {"objective": 5410, "buildSeconds": 0.004, "solveSeconds": 0.03,
            "candidates": 12, "seatVariables": 79}
}
```

- `status`: `optimal` or `feasible` (time ran out with a solution); `unknown` means no solution in
  time, with empty proposals and everyone unseated.
- `checks` are machine keys for the approval screen; its copy (en, es-419) lives in the app.
  `nearbyFirst` is true when every member is within 5 blocks (`near`).
- `rejectedAlternative` is the best grouping that breaks some weighted soft rule more than the
  proposal (or seats fewer: `brokenRule: "fewerSeated"`), with the rule that costs it most and
  its objective loss. `null` when nobody can be seated.
- `check(data, result)` returns `[{"rule", "rondaId", "uids"}]`, one per broken hard rule, and is
  empty when the groups are valid. `score(data, result)` gives seated count, soft-rule units and
  objective for any result.

## Rules

Candidate rondas are barrio × pretext × slot, one each, so groups have no symmetry. Candidates
fewer people may join than their floor get no variables. Each rule is one named literal in
`ronda_solver/rules.py` and one method in `ronda_solver/model.py`.

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

## Limits

- One ronda per barrio × pretext × slot: twelve fútbol players in one barrio and slot seat ten.
- Season runs only: there is no input for existing rondas and their members, so refill (ronda at
  4) and merge (ronda at 3) are not built yet.
- The alternative is a second solve after the first: allow `maxTimeInSeconds` +
  `alternativeTimeInSeconds` (8 + 2 s by default) in the callable.
- CP-SAT uses every core. With 8 workers 200 invented people solve to optimality in 2–7 s; with
  1–4 workers the 8 s limit returns `feasible` (slightly fewer seated). 30 people take < 0.1 s.
