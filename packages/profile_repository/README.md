# profile_repository

Repository layer. A member's `Profile` ("lo que traés") on `users/{uid}`, and the conditions they
accepted on the welcome screen, over `ronda_api`. It turns `UserDocument` into domain models and
back; it never handles needs, which stay on the phone in `needs_repository`.

## API

| Member | Does |
|---|---|
| `ProfileRepository(rondaApi: RondaApi)` | Built in bootstrap; tests pass a mocked `RondaApi` |
| `Stream<Profile?> watchProfile(String uid)` | The profile, or `null` until firstName, ageBand and barrio are saved (a document holding only `terms` reads as `null`) |
| `Future<void> acceptTerms(String uid, TermsAcceptance)` | Writes `terms {version, acceptedAt}`; throws `AcceptTermsFailure` |
| `Future<void> createProfile(String uid, Profile)` | Writes the profile, keeping `terms`; throws `SaveProfileFailure` |

## Models

Each enum carries its stored `id` and a `fromId` that returns `null` for unknown ids (dropped,
never thrown):

- `Pretext`: `mate`, `truco`, `futbol5`, `caminata` (the solver's ids).
- `Barrio`: the nine Ciudad de la Costa barrios of `solver/fixtures/invented_demo_30.json`
  (`solymar-norte`, …). No id contains `_`, since seat ids join barrio, pretext and slot with it.
- `AgeBand`: `18-29`, `30-39`, … `80+`.
- `Bring`: `pan`, `yerba`, `termo`, `sillas`, `enseno-truco`, `tengo-ganas`.
- `Slot(SlotDay, SlotBand)`: id `{day}-{band}`, e.g. `sat-afternoon`.
- `Profile`, `TermsAcceptance(version, acceptedAt)`.

Lists are written in the enums' declaration order, so the same choices always produce the same
document. UI labels come from the app's l10n.

## Tests

```sh
very_good test --coverage --min-coverage 100
```
