# needs_repository

Repository layer. A member's `Needs` ("lo que te complica ir"), kept on the phone only, and the
seat filter they drive.

**This repository has no network path.** It depends only on `device_store` (by path) and
`equatable`: never on Firebase, `http` or any other client. Needs never leave the device; the
server receives only the seat ids that `eligibleSeatIds` returns (see `docs/ARCHITECTURE.md`
§ Thesis: split by sensitivity).

## API

| Member | Does |
|---|---|
| `NeedsRepository(deviceStore: DeviceStore)` | Built in bootstrap; tests pass a mocked `DeviceStore` |
| `Future<Needs> read()` | The saved needs; `Needs.none` when nothing is saved or the value can't be read |
| `Future<void> save(Needs)` | One JSON value under `NeedsRepository.storageKey` (`needs`) |
| `Future<void> clear()` | Deletes that key |
| `List<String> eligibleSeatIds(Needs, List<SeatFacts>)` | Pure: the ids of the seats the needs allow, in input order |

## Models

- `Need`: `walkALot` (caminar mucho), `climbStairs` (subir escaleras), `returnAfterDark`
  (volver de noche), `noCar` (no tengo auto). UI labels come from the app's l10n, not from here.
- `Needs(Set<Need> values)`, Equatable; `Needs.none` is the empty set.
- `SeatFacts(seatId, walkDistance, hasStairs, endsAfterDark, needsCar)`, one per seat.
  `WalkDistance`: `near` (≤ 5 blocks), `medium` (≤ 10), `far`.
- `WalkDistance.fromBlocks(num)` bands a walk; `WalkDistance.forMember(memberBarrio:, blocksFrom:)`
  reads the member's barrio from a seat's `blocksFrom` table (`seat_facts/{seatId}`, see
  `docs/ARCHITECTURE.md` § Data model). A barrio the table doesn't list reads as `far`, so a seat
  the phone can't place never passes "caminar mucho".

## Filter rules

| Need | Drops seats where |
|---|---|
| `walkALot` | `walkDistance == WalkDistance.far` |
| `climbStairs` | `hasStairs` |
| `returnAfterDark` | `endsAfterDark` |
| `noCar` | `needsCar` |

No needs keeps every seat. Several needs drop every seat any one of them drops.

## Stored format

```json
{"needs":["walkALot","noCar"]}
```

The `Need` value names are the on-disk contract: renaming one drops it from every phone that
saved it. Unknown names and non-text entries are skipped; anything that isn't this shape reads
as `Needs.none`.

## Tests

`test/src/needs_repository_test.dart` also runs the filter over the repo's invented demo seats,
`../../data/demo/invented_seat_facts.json`, so the demo data and the filter can't drift apart.

```sh
very_good test --coverage --min-coverage 100
```
