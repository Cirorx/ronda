# voice_recorder

Data layer. Records one voice note at a time with [record](https://pub.dev/packages/record) as
the WAV Voice Transcribe takes: RIFF/WAVE, 16 kHz, mono, 16-bit PCM (`VoiceRecorder.config`;
`record` defaults to AAC 44.1 kHz stereo). No gain, echo or noise processing on the phone.

| Member | Does |
|---|---|
| `hasPermission()` | Whether the microphone may be used; asks the first time |
| `start()` | Starts a note: a file in the temporary directory on a phone, memory on web |
| `stop()` | The note's WAV bytes, or `null` when nothing was recording. On a phone the file is deleted once read; on web the bytes come from the blob URL `record` returns |
| `cancel()` | Stops and throws the note away |
| `dispose()` | Releases the microphone |

It holds no domain logic and logs nothing. Only bootstrap constructs it; `onboarding_repository`
receives it through its constructor. Tests pass a mocked `AudioRecorder` and fake file helpers.

## Tests

```sh
very_good test --coverage --min-coverage 100
```
