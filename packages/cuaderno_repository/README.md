# cuaderno_repository

Repository layer. El cuaderno del barrio (`docs/PRODUCT.md` § El cuaderno del barrio): one line a
day about what the person noticed, a postcard drawn from the week's lines, and one line to bring
to the meeting. Over `device_store`, `voice_recorder`, `ronda_api`'s `CuadernoApi` and
`share_sheet`.

| Member | Does |
|---|---|
| `read(uid)` / `saveEntry` / `deleteEntry` / `bring` / `clear` | The cuaderno, in `device_store` under `cuaderno.{uid}`. No network path |
| `changes` | Fires when the cuaderno changes on this phone |
| `startVoiceNote()` / `voiceLevels()` / `discardVoiceNote()` / `readVoiceLine(uid)` | A short voice note: uploaded to `audio/{uid}/…`, read by `read_line` (Voice Transcribe), deleted once read. Returns the words; writes nothing |
| `makePostcard(lines)` | The week's lines go up as the payload of `make_postcard`; the JPEG comes back. Stored nowhere |
| `sharePostcard(postcard, title:)` | The share sheet: save to the phone, send |

The entries never leave the phone: a test checks that no write, read or delete of the cuaderno
touches `RondaApi` or `CuadernoApi`. Failures: `VoiceLineFailure` (with a `VoiceLineProblem`),
`NothingToDrawFailure`, `MakePostcardFailure`, `SharePostcardFailure`.

## Tests

```sh
very_good test --coverage --min-coverage 100
```
