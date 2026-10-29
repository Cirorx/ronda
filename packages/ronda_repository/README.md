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

Every failure is a `ProposalsFailure` whose `reason` is `forbidden` (no admin claim: the rules or the
callable refused) or `other`.

## Models

- `Proposal`: id, `ProposalStatus` (pending, approved), `rondas`, `unseatedCount`, `createdAt`, and
  `rejectedReason`, the solver's es-419 sentence on why the next-best grouping lost.
- `ProposedRonda`: seat, barrio, pretext and slot ids and the members; `allWithinTenBlocks` and
  `sixtyPlusCount` back the approval checks.
- `ProposedMember`: uid, first name, age band id, `distanceBlocks`, and `plusOneInGroup` (`null`
  when their +1 did not sign up).
