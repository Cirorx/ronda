# organiser_repository

Repository layer. The organiser agent as the app sees it, over `ronda_api`'s `OrganiserApi`
(#49, `docs/ARCHITECTURE.md` § Organiser agent):

- for the admin, the trace: the newest runs and each run's steps as they land, the members'
  [Algo estuvo mal] taps, and the rain check run by hand, now or as if it were a given time;
- for a ronda's members, the acta ("Lo que hizo el programa") of its newest week, and the tap;
- for a ronda's host, the rain proposal and their pick.

The words in the models are the server's es-419 (like the pushes); the app shows them as they
are.

## API

| Member | Does |
|---|---|
| `OrganiserRepository(organiserApi: OrganiserApi)` | Built in bootstrap; tests pass a mocked `OrganiserApi` |
| `Stream<List<AgentRun>> watchRuns()` | The newest runs, newest first |
| `Stream<List<AgentStep>> watchSteps(String runId)` | A run's steps in order |
| `Stream<int> watchFlagCount(String rondaId)` | [Algo estuvo mal] taps on that ronda's acta |
| `Stream<Acta> watchActa(String rondaId)` | The newest week with lines, oldest line first |
| `Future<void> reportActa({rondaId, uid, week})` | Records [Algo estuvo mal] |
| `Stream<RainMove?> watchMove(String rondaId, String week)` | The rain proposal; choices this app doesn't know are left out |
| `Future<MoveAnswer> answerMove({rondaId, week, MoveChoice choice})` | Sends the pick once (`already` on a repeat) |
| `Future<RainCheckResult> runRainCheck({DateTime? at})` | Runs the rain check now, or at `at` |

Every failure is an `OrganiserFailure`: `forbidden` (not the admin, not a member, not the host),
`late` (the pick came after 21:00) or `other`.
