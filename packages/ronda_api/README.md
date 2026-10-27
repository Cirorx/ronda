# ronda_api

Data layer. Ronda's client over Firebase: Firestore documents in their wire shape, and the Cloud
Functions callables once the first one exists. No domain logic; repositories turn what it returns
into domain models.

Depends on `cloud_firestore`. The `FirebaseFirestore` instance is built in bootstrap (pointed at
the Firestore emulator in the development flavor) and passed in. Callables join as a
`FirebaseFunctions` built with `FirebaseFunctions.instanceFor(region: RondaApi.region)`: without
the region the plugin calls `us-central1`.

## API

| Member | Does |
|---|---|
| `RondaApi(firestore: FirebaseFirestore)` | Built in bootstrap; tests pass `FakeFirebaseFirestore` |
| `RondaApi.region` | `southamerica-east1`, where every function and callable runs |
| `RondaApi.usersCollection` | `users`, one document per Firebase uid |
| `Stream<UserDocument?> watchUser(String uid)` | `users/{uid}` now and on every change; `null` while it doesn't exist |
| `Future<void> saveTerms(String uid, TermsRecord)` | Merges `terms {version, acceptedAt}`, creating the document if needed |
| `Future<void> saveProfile(String uid, {firstName, ageBand, barrio, slots, pretexts, brings})` | Merges the profile fields and a server `createdAt` |

## Models

- `UserDocument`: `users/{uid}` as stored. Every field is optional on the wire, because the terms
  arrive first (a welcome door) and the profile later (onboarding saved); fields of the wrong
  type are skipped. Existence alone does not mean onboarding is done.
- `TermsRecord(version, acceptedAt)`: `acceptedAt` is a Firestore `Timestamp` on the wire.

The `users/{uid}` fields are in `docs/ARCHITECTURE.md` § Data model; `firestore.rules` allows
only those, typed. Needs, mood and audio never go through this client.

## Seat facts and eligible seats (`EligibleSeatsApi`)

An extension on `RondaApi` in `lib/src/seat_facts/`, so it stays apart from the profile methods.
The shapes are in `docs/ARCHITECTURE.md` § Data model.

| Member | Does |
|---|---|
| `Future<List<SeatFactsDocument>> readSeatFacts()` | Every `seat_facts/{seatId}` document; one without the seat shape is skipped, so it never passes the filter |
| `Future<void> writeEligibleSeatIds({uid, seatIds})` | Replaces `users/{uid}/private/eligible` with exactly `{seatIds, updatedAt: serverTimestamp}` |
| `SeatFactsDocument.fromJson(seatId, json)` | The wire model: barrio, pretext, slot, `blocksFrom`, `hasStairs`, `endsAfterDark`, `needsCar`; throws `FormatException` on another shape |

Extension methods can't be stubbed with mocktail: a repository test over them passes a real
`RondaApi` built on `FakeFirebaseFirestore`.
