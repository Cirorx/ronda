# ronda_repository

Repository layer. Rondas and the admin's proposals, over `ronda_api`'s `ProposalsApi`: the solver's
groups waiting for approval, approving them into rondas, and taking an approval back. Ids stay as
stored (`lagomar-sur`, `mate`, `sat-afternoon`): a repository imports no other repository, so the
app reads them with `profile_repository`'s enums for their labels.

## API

| Member | Does |
|---|---|
| `RondaRepository(proposalsApi: ProposalsApi)` | Built in bootstrap; tests pass a mocked `ProposalsApi` |
| `Stream<Proposal?> watchLatestProposal()` | The newest `proposals/{id}`, or `null` while there is none; errors with `ProposalsFailure` |
| `Future<String> proposeGroups()` | Calls `propose_groups`; returns the new proposal's id |
| `Future<void> approveProposal(String id)` | Calls `approve_proposal`, which writes `rondas` and their `members` |
| `Future<void> undoApproval(String id)` | Calls `approve_proposal` with `undo`: deletes those rondas, back to pending |
| `Future<RondaCandidates> rondaCandidates(String rondaId)` | Calls `ronda_candidates`: who is in the ronda, who could join, what doesn't match |
| `Future<AddedToRonda> addToRonda({rondaId, uid, move})` | Calls `add_to_ronda` ("Sumar a esta ronda"); `move` takes them out of their ronda |
| `Future<PilotNumbers> pilotNumbers()` | Calls `pilot_numbers`: the pilot's counts, each as `CountOf` (x of y) |

Every failure is a `ProposalsFailure` whose `reason` is `forbidden` (no admin claim: the rules or the
callable refused), `full` or `alreadyIn` (`add_to_ronda` only), or `other`.

## Models

- `Proposal`: id, `ProposalStatus` (pending, approved), `rondas`, `unseatedCount`, `unseated`
  (`UnseatedPerson`: first name, barrio, slots, pretexts), `createdAt`, and `rejectedReason`, the
  solver's es-419 sentence on why the next-best grouping lost.
- `ProposedRonda`: seat, barrio, pretext and slot ids, the members and, once approved, `rondaId`;
  `allWithinTenBlocks` and `ageChecks` (one `AgeGroupCheck` per `AgeGroup`, the solver's three)
  back the approval checks.
- `RondaCandidates`, `Candidate` (with `CandidateWarning`s) and `AddedToRonda`: "Sumar a esta
  ronda".
- `PilotNumbers`, `PilotRonda`, `PilotWeek`, `PilotSeguimos`, `CountOf`: the numbers panel.
- `ProposedMember`: uid, first name, age band id, `distanceBlocks`, and `plusOneInGroup` (`null`
  when their +1 did not sign up).
