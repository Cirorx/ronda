# flyer_repository

Repository layer. The host's "Un mate de más" flyer (`docs/PRODUCT.md` § Flyers), over
`face_blur`, `ronda_api`'s `FlyersApi` and `share_sheet`.

| Member | Does |
|---|---|
| `canBlurFaces` | `false` on web: no flyer there ("Hacelo desde la app del teléfono") |
| `takePhoto(source)` / `retrieveLostPhoto()` | The photo of the group's things, as an opaque `TakenPhoto` |
| `blur(photo)` / `blurTappedFace(photo, x:, y:)` | The `BlurredPhoto` the preview shows |
| `makeMateFlyer(uid:, rondaId:, photo:)` | Uploads the blurred JPEG to `flyer_photos/{uid}/{id}.jpg`, awaits `make_mate_flyer`, downloads the flyer and returns a `MateFlyer` |
| `shareFlyer(flyer, title:)` | The share sheet: print, WhatsApp, save |

`makeMateFlyer` takes only a `BlurredPhoto`, which only `face_blur` makes, so a photo whose faces
weren't blurred has no way to the upload. Failures: `TakePhotoFailure`, `BlurPhotoFailure`,
`NotAHostFailure`, `NothingToCutOutFailure`, `MakeFlyerFailure` (after deleting a photo the
callable may not have reached) and `ShareFlyerFailure`. It re-exports `BlurredPhoto`,
`TakenPhoto` and `PhotoSource`, so the app imports no data package.

## Tests

```sh
very_good test --coverage --min-coverage 100
```
