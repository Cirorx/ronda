# onboarding_repository

Repository layer. Onboarding by voice, over `voice_recorder` and `ronda_api`.

| Member | Does |
|---|---|
| `startVoiceNote()` | Starts recording; `MicrophoneDeniedFailure` without the microphone, `StartVoiceNoteFailure` when the recorder fails |
| `discardVoiceNote()` | Stops and throws the note away ("Borrar y empezar de nuevo", "Cancelar") |
| `readVoiceNote(uid)` | Stops the note, reads `users/{uid}.terms`, uploads to `audio/{uid}/{noteId}.wav`, awaits `extract` and returns a `VoiceSignup` |

`readVoiceNote` refuses to upload while `users/{uid}.terms` is missing (`TermsNotAcceptedFailure`);
the Storage rules and the callable check the same. `VoiceNoteNotUnderstoodFailure` means the note
was read (and deleted) and nothing came of it; `ReadVoiceNoteFailure` is anything else, after
deleting a note the callable may not have reached. Storage's 1-day lifecycle rule on `audio/` is
the backstop.

`VoiceSignup` carries the stored ids (`60-69`, `solymar-norte`, `tue-afternoon`): this repository
imports no other repository, so the cubit reads them with `profile_repository`'s `fromId`. Needs
are never part of it: they stay on the phone.

## Tests

```sh
very_good test --coverage --min-coverage 100
```
