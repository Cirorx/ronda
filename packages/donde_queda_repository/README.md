# donde_queda_repository

Repository layer. ¿Dónde queda?, the ronda's weekly barrio photo game (`docs/PRODUCT.md` § The
weekly loop), over `face_blur` and `ronda_api`'s `DondeQuedaApi`.

| Member | Does |
|---|---|
| `watch(rondaId:, uid:)` | This week's `DondeQuedaGame` as this member sees it (their turn, posted, guessed) and last week's `DondeQuedaReveal` |
| `canBlurFaces` | `false` on web: the photo is taken from the phone app; guessing works everywhere |
| `takePhoto` / `retrieveLostPhoto` / `blur` / `blurTappedFace` | The same `face_blur` steps as the flyer |
| `post(uid:, rondaId:, week:, photo:, line:, hint:, pin:)` | Uploads the blurred JPEG to `donde_queda_photos/{uid}/{id}.jpg` and awaits `post_donde_queda` |
| `pass(rondaId:, week:)` | "Esta semana no" |
| `guess(rondaId:, week:, pin:)` | The member's one pin |
| `photo(path)` | The week's published photo |

`post` takes only a `BlurredPhoto`, which only `face_blur` makes. Failures: `TakePhotoFailure`,
`BlurPhotoFailure`, `PhotoRefusedFailure` (with a `PhotoRefusal`: `houseNumber`, `person`,
`empty`, `words`), `NotYourTurnFailure`, `AlreadyGuessedFailure` and `DondeQuedaFailure`.

## Tests

```sh
very_good test --coverage --min-coverage 100
```
