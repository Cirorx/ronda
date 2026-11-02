# live_transcript

Data layer. Shows a neighbour's words while they talk. The recorder's samples
(`voice_recorder`, streaming mode) go to Ronda's **relay**, a small server of ours that holds the
Meta key and sits in front of Voice Transcribe's realtime mode
(`wss://api.meta.ai/v1/asr/realtime`); the transcript comes back as it grows. The phone never
holds the key and never talks to Meta.

| Member | Does |
|---|---|
| `LiveTranscriptClient(url:, idToken:)` | Opens a session with the relay: the member's Firebase ID token and the surface (`signup`, `line`, `plan`) in the first frame, then raw PCM |
| `LiveTranscription` | One session: `add(pcm)`, `words` (the whole text so far, revised), `finish()` → the final transcript or `null` |
| `LiveVoiceNote(recorder:, client:)` | One note: records, streams while the session is up, and `stop()` answers with the WAV and the transcript when live saw it through |

Live is best effort. A session that can't open within 4 s, drops, falls more than 4 s behind, or
is slow to answer after the note ends turns live off for that note: `stop()` answers with no
transcript and the repository reads the WAV the usual way (upload, `extract`). Nothing is stored
and nothing is logged. Only bootstrap constructs the client, with the relay's URL from
`--dart-define=LIVE_TRANSCRIPT_URL=…`; with no URL there is no client and every note takes the
usual way.
