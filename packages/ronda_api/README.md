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
| `Stream<bool> watchUserExists(String uid)` | Whether `users/{uid}` exists, now and on every change |

The `users/{uid}` fields are in `docs/ARCHITECTURE.md` § Data model; the profile itself arrives
with onboarding.
