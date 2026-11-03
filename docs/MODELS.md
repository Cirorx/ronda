# Models, partners and dev tools

Checked 2026-10-26 against https://dev.meta.ai/docs/models and the Meta Model API console.
Prices per million tokens unless noted.

## Meta Model API (runtime models we use)

| Model | Id | Use in Ronda | Price |
|---|---|---|---|
| Muse Voice Transcribe | `muse-voice-transcribe-1.0` (`POST /v1/asr/transcribe`, real-time `wss://api.meta.ai/v1/asr/realtime`) | Voice onboarding, voice RSVP, host recap, "Decilo vos" in Algo chico esta semana | $0.18 / hour |
| Muse Spark 1.3 | `muse-spark-1.3` | Structured fields from transcripts, and a member's own small plan (`{activity, day, time, place}` plus kind and a topic flag, `functions/small_plans.py`); ¿Dónde queda?'s answer line and hint; whether a small plan may be shown to the ronda (`functions/shared_plans.py`: a public place, no address, phone number or money); fallback for the agent | $1.25 in · $0.15 cached · $4.25 out |
| SAM 3.1 | `sam-3.1` (Responses API, Files API) | Cut objects out of a ronda photo for the flyer; ¿Dónde queda?: find people, number plates and house numbers; spot photo outline | $2.50 / 1,000 images; video $0.20 / 1,000 frames |
| Muse Image 1.0 | `muse-image-1.0` (`/v1/images/generations`, `/v1/images/edits`) | "Mate de más" and tear-off flyer layouts | $0.01 / image |

Notes:
- Spark 1.3 audio understanding is "not fully supported"; audio always goes through Voice
  Transcribe first. Spark 1.2 is the documented choice if audio must go straight in.
- Voice Transcribe: 25 evaluated languages with code-switching (Meta's speech-to-text page names
  Spanish and Portuguese); rioplatense is untested — check on day 2 with real notes.
  - **WAV only:** RIFF/WAVE, mono, 16-bit PCM, 16 or 24 kHz; ≤ 10 min, ≤ 32 MB. The body is
    multipart: a `request` JSON part and an `audio` part.
  - `languageBias` takes language **names** (`["Spanish"]`, not `es`); omit it to auto-detect.
    `keywords` biases toward names (barrios, "truco", "bizcochos"). Metered per second.
- API base `https://api.meta.ai/v1`, `Authorization: Bearer $MODEL_API_KEY`; OpenAI-compatible
  (Chat Completions and Responses) and Anthropic-compatible. Use the `openai` Python SDK with
  `base_url`. Differences that break OpenAI code: only `n=1`; `stop`, `logprobs` and
  `logit_bias` return 400; on Spark 1.3 `tool_choice` accepts only `"auto"`; a long
  non-streaming request can return 504, so stream.
- Spark 1.3 structured output: `response_format` `json_schema` with `strict: true` is enforced.
  Strict subset: root object, every key `required`, `additionalProperties: false`, no
  `oneOf`/`allOf`. `client.beta.chat.completions.parse(response_format=PydanticModel)` works.
- SAM 3.1 (`POST /v1/responses`): one short noun phrase per request plus the image as a data URL.
  It streams boxes and base85 masks placed relative to their box, not PNGs: decode with
  `meta-sam-parser`. Spanish prompts ("termo") are untested; try English ("thermos") too.
- Muse Image: `n` 1–10, `size` sets the aspect ratio only, `output_format` png; edits take 1–10
  reference images and no mask. Text quality isn't documented: draw the copy and the QR in code.
- Rate limits are per team: Spark 1.3 3,000 RPM / 4M TPM; SAM 3,000 RPM; Muse Image 150 RPM.
  Retry 429/500/503 with backoff; a 402 `billing_not_configured` means no card.
- No text-to-speech, no embeddings in the API. Read-aloud uses the phone's own voice.
- **Never use Contributor variants with member data**: Meta trains on those inputs.
- Standard mode doesn't train on our data. Zero data retention needs Meta's sales team.
- Uruguay isn't on the restricted list; the first paid call confirms access.

## Voice Transcribe in real time (#64, `relay/`, `packages/live_transcript`)

Measured 2026-11-01 from Uruguay with `scripts/smoke/s9_realtime.py` on an invented 10.5 s
note streamed at real time in 80 ms frames (`PCM_16KHZ`, `PUSH_TO_TALK`, `CUMULATIVE`,
Spanish bias, Ronda's keywords); the eval in `evals/voice/` repeats it and keeps the numbers:
- connect 1.2 s (TLS handshake from Montevideo), ack right after the handshake frame;
- **first words 0.7–0.8 s after the first audio frame**, then a revised cumulative partial every
  0.2–0.6 s (24–27 per note);
- **final transcript 0.24 s after `endStream`**, close code 1000; the transcript matched the
  reference word for word, batch missed one word (WER 0.06).
- Batch (`POST /v1/asr/transcribe`, same note): 3.2 s for the whole round trip. So live cuts the
  wait after "Terminé" from ~4 s + upload to ~0.3 s, leaving Spark's ~2 s.

Protocol as observed (docs: dev.meta.ai/docs/speech-to-text): the key goes **only** in the first
JSON frame (`authorization.accessToken: "Bearer …"`; the HTTP header is ignored); audio as
binary frames paced at real time (no more than 5 s ahead, idle input closes the session);
`{"type":"endStream"}` ends input and the server flushes, then closes. Close codes: 1000 done,
1008 bad request or pacing, 1011 backend (retry), 1013 rate limited (256 concurrent streams,
16,000 per hour per tenant). Sessions last up to 60 min. Billing $0.18/h, same as batch.

**Decision: a relay, not a client token.** Meta offers no short-lived client credential for the
realtime endpoint: the only thing it accepts is the Model API key inside the handshake frame, so
a phone that spoke to Meta directly would hold the key. Python Functions are WSGI and can't hold
a WebSocket, so the relay is a small Cloud Run service (`relay/main.py`, `websockets` +
`firebase-admin`, `southamerica-east1`, `scripts/deploy_relay.sh`): it verifies the member's
Firebase ID token and `users/{uid}.terms`, opens the Meta session with the key from Secret
Manager, pipes the PCM one way and only `transcript` events the other, caps a note at 65 s of
audio, stores nothing and logs session ids, bytes and timings only. The app reaches it through
`--dart-define=LIVE_TRANSCRIPT_URL`; with no URL (the default) nothing changes: the note is
uploaded and read as before, which is also the fallback whenever live fails (connect, ready,
backlog, a dropped socket, a late final) and when `read_transcript` fails.

**The upload path in two calls (2026-11-02).** So the wait screen can show real steps and the
words before the fields, the app no longer calls `extract` with `{path}` alone: it calls
`extract` with `{path, stage: "listen"}`, which runs Voice Transcribe, deletes the note and
answers `{transcript}`, then `read_transcript` with those words, the same callable the live path
uses. `{path}` alone still does both in one call, for builds that predate this.

## Open weights

| Model | Where | Use |
|---|---|---|
| Muse Spark Open (816B MoE, 42B active; text, image, audio, video in; released 2026-10-15; Muse Model License) | Baseten: OpenAI-compatible `https://inference.baseten.co/v1/chat/completions`, hackathon id `meta-models/muse-spark-open-1026`. Modal: shared per-token endpoint. | The organiser agent (targets the open-weights and agentic bonuses); picks three of the small-plan ideas code built (`functions/plan_suggestions.py`) |
| Muse Glimmer (30B, Apache 2.0, single GPU, 17–20 GB quantised) | Self-host only (not on Baseten or Modal); Fireworks serverless fine-tuning | Not in the build. After: a rioplatense-register judge |
| Llama 3.2 1B | Phone (ExecuTorch / llama.cpp) | Stretch only: not on the hackathon's model list |

**Spark Open on Baseten (corrected 2026-10-26):** Baseten documents tool calling on all its Model
APIs, Spark Open included, but it **accepts `json_schema` without enforcing it** for Spark Open,
so validate every tool argument in code. Spark Open always reasons and defaults to
`reasoning_effort: "xhigh"`; send `low` or `medium` and stream. It emits tool calls in its own
"ATEM" format that Baseten parses; raw `<atem:` text in `content` means the parser failed.
Default limits: 15 RPM unverified, 120 RPM verified; the hackathon credit adds 2M TPM if
approved. Modal (`https://inference.us-west.modal.direct`, proxy token `wk-…`) is a backup only:
its tool support isn't documented. Fallbacks, in order: a JSON action list validated with
pydantic; the agent on `muse-spark-1.3` (loses the open-weights bonus for those calls).

**As built in #49** (`functions/organiser/model.py`, docs/ARCHITECTURE.md § Organiser agent): the
agent streams Chat Completions to `meta-models/muse-spark-open-1026` with `tools` and
`extra_body={"reasoning_effort": "low"}`, gathering each tool call's id, name and argument
fragments by index as `s4_baseten_tools.py` does. An SDK or connection error, or `<atem:` in the
answer, moves the rest of the run to `muse-spark-1.3` on the Meta Model API (same request; no
`tool_choice`, so "auto"). Every argument is validated with pydantic and retried once with the
error; answers are Markdown-stripped. No paid call ran while building it: the tests play back
scripted turns shaped like the smoke test's stream. The first real runs, the weekly card on
ronda-uy and the rain check over the Firestore stand-in, are in § Results on the current code.

## Per job: why each model, and what happens when it fails

The README keeps one short line per job; this is the long form. The numbers behind it are in
§ Results on the current code and § Rondas that form themselves, below.

- **Hear a spoken sign-up** (also the cuaderno's lines and a spoken small plan): Muse Voice
  Transcribe (`muse-voice-transcribe-1.0`, `POST /asr/transcribe`). Meta's speech-to-text, biased
  to Spanish with 114 keywords (every barrio, "truco", "bizcochos"). Live mode
  (`wss://…/asr/realtime` through `relay/`) is built and off by default; on 2026-11-02 it gave the
  first words 0.7 s after speaking started and all of them 0.25 s after stopping (n = 1,
  [`evals/voice`](../evals/voice/RESULTS.md)). If it fails: 429 and 5xx are retried twice, then
  "No pudimos leer el audio" and [Prefiero tocar botones], the same sign-up by taps.
- **Turn those words into the sign-up's fields:** Muse Spark 1.3 (`muse-spark-1.3`) at
  `reasoning_effort: low`. The Meta Model API enforces a strict `json_schema`, so name, age band,
  barrio (one of 71), pretexts, slots and what they bring come back as the app's own ids, or
  `unknown`. If it fails: the read-back screen, where the person checks and edits every field;
  on an error, the buttons.
- **The organiser agent** (the rain check: forecast, sunset, last bus, the next city buses in
  Montevideo, who's coming, then a proposal to the host; the weekly card; the bench; the place,
  hour and host of a ronda that formed itself): Muse Spark Open
  (`meta-models/muse-spark-open-1026`) on Baseten. Open weights with tool calling; at
  `reasoning_effort: low` a turn takes about 1.5 s. If it fails: Spark 1.3 on the Meta Model API
  for the rest of the run, on an error or raw `<atem:` text. With no model at all, code goes on
  alone: the fixed card, the bench's default deadline, no rain proposal, a new ronda's nearest
  open place at the band's usual hour.
- **Cut the group's things out of the host's photo for the flyer** (also find the people, plates
  and house numbers ¿Dónde queda? blurs): SAM 3.1 (`sam-3.1`, Responses API). Segmentation from
  a short noun phrase; boxes and masks come back, decoded with `meta-sam-parser` into clean
  cutouts. The termo, the mazo and the mates are looked for side by side, beside Muse Image. If
  nothing usable is found: "No encontramos el termo, el mazo ni los mates. Probá con otra foto";
  on an error, "Probá de nuevo en un rato". The tear-off flyer (`scripts/flyer.py`) uses no
  model.
- **Paint the flyer's background** (also the cuaderno's postcard): Muse Image
  (`muse-image-1.0`). It paints the scene with no people and no text, from a prompt that names
  the place in full. If it fails: 429 and 5xx are retried twice, then "No pudimos hacer el
  volante. Probá de nuevo en un rato", or the tear-off flyer.

## Results on the current code (2026-11-02, #61)

Measured from Uruguay on main at 7989262 by calling the functions' own code with the real keys
(loaded by `scripts/smoke/_env.py`, never printed): `voice_signup.transcribe` and `read_fields`;
`rain.run_rain_check` over the Firestore stand-in (`functions/tests/organiser_fakes.documents()`,
Wednesday 18:00, the rainy stand-in forecast) with `organiser.model.from_environment()`;
`weekly_card` through `evals/card` (`--live --record`); and `mate_flyer.run_models` with the real
`MetaSam` and `MuseImage`. Nothing was written to ronda-uy, and the whole round cost about $0.15.
The README's models table quotes these numbers.

- **Voice Transcribe** (batch, the path the app takes): the invented 10.5 s note from
  `evals/voice/make_note.sh`, 3 calls, 3.9, 2.3 and 2.4 s, $0.0005 each. Two transcripts had
  every word; the third doubled "mate" and dropped two full stops. The keyword list is 114 long
  now (109 on 11-01, before the new pretexts and brings).
- **Spark 1.3** `read_fields` on those transcripts: 4.3, 2.8 and 2.5 s; 2,135–2,137 tokens in,
  424–440 out; $0.0045 each. The same fields every time (Marta, 60-69, solymar-norte, mate,
  sat-afternoon, termo and pan, since "bizcochos" counts as pan).
- **Spark Open, the rain check**, 2 runs: both `done` on Spark Open with no fallback, one
  proposal to the host and one push each. Turns took 1.2–2.5 s.
  - Run 1: 6 turns, 11.0 s of model time, 15,675 in / 1,625 out, $0.027. `get_forecast`, then
    `get_sunset`, `get_last_bus` and `count_rsvps` in one turn, `propose_move` (the covered
    salon, or Friday), then `log_acta` twice: the first summary ran past 200 characters, the
    pydantic check refused it, and the retry was shorter.
  - Run 2: 5 turns, 8.1 s, 12,546 / 1,285, $0.021, the salon and no other day.
- **Spark Open, the weekly card**: `evals/card` again, 3 cards, 7.5–7.9 s, 9,306–9,822 in /
  907–1,293 out, $0.016–0.018, 2 from the model and 1 template, every call and block valid
  ([`evals/card/RESULTS.md`](../evals/card/RESULTS.md)). On ronda-uy, the dispatcher's own run
  for the demo ronda `demo-ronda-card62` (its `agent_runs` trace): 4 turns, 6.1 s of model time
  (2.1, 1.5, 1.1 and 1.3 s), 7.9 s from start to end, 10,596 in / 1,011 out, $0.018.
- **SAM 3.1 and Muse Image** through `run_models`, on a photo of a thermos, two mates and a deck
  of cards that Muse Image painted for the test (17.3 s, $0.01):
  - Side by side 17.9 s, which is Muse Image's background (17.9 s).
  - SAM "thermos" 3.6 s (1 mask) and "deck of playing cards" 3.8 s (1), but "mate gourd" 5.3 s
    and "gourd" 3.4 s found nothing, so the flyer came out with the termo and the mazo only.
  - Asked alone: "cup" (4.7 s) and "bowl" (3.8 s) found nothing; **"pot" (3.6 s) found both
    mates**; "thermos" 2.6 s. That was one painted photo: try "pot" in `mate_flyer.OBJECTS` on a
    real one.
  - 8 SAM calls at $0.0025, 2 images at $0.01.
- **On ronda-uy**, read-only (Cloud Run request logs, Firestore, Storage):
  - `extract` 3 × 200 on 11-01 (11.8, 12.5 and 19.1 s, the one-call path);
  - `read_line` 1 × 200 on 11-02 (13.9 s: Voice Transcribe and Spark 1.3 for a cuaderno line);
  - `propose_groups` 2 × 200 on 11-02 (4.1 and 0.9 s, the solver `optimal`, no group yet);
  - never called: `read_transcript` and `make_mate_flyer` (no `flyers/` documents or objects);
  - not deployed: the realtime relay.
- **The functions' `log.info` timings don't reach Cloud Logging.** The `extract … transcribe N
  ms, fields N ms`, `make_mate_flyer …` and `weekly_card: …` lines are dropped, because nothing
  sets Python's logging level below WARNING in `main.py`, so only warnings show. Until it does,
  production numbers per model come from the `agent_runs` traces, which keep each turn's
  latency and tokens, and from request latencies.

## Rondas that form themselves: the agent's setup (2026-11-03)

`scripts/smoke/s12_auto_setup.py` runs `functions/auto_setup.set_up` on Spark Open on Baseten
alone (no fallback) for two invented neighbours in Cordón who want mate on Thursday afternoons,
with three invented places: a library closed in the afternoon, a plaza and a rambla. Six runs,
in two rounds of three, from Uruguay:

- Every run `propose_setup:ok` on the first call, 2 turns (the call, then one sentence): 3.1 to
  4.3 s from start to end, 2,525 to 2,591 tokens in and 445 to 820 out, about $0.005 a group.
- It chose the rambla each time ("es ideal para el mate"), never the closed library, at 16:00
  (once 15:30), with Ana opening; code accepted every field.
- The first round wrote the reason to the member ("vos Ana podés abrir"); the system prompt now
  asks for third person with an example, and the second round followed it.

## Meta tooling for building

Counts toward "Use of Meta AI tooling" (25% of the score); mention what was used in the README.

- **Muse Code CLI:** `curl -fsSL https://dev.meta.ai/install.sh | sh`, then `muse`,
  `muse exec "<prompt>"` or `muse serve`. It reads `META_API_KEY` (not `MODEL_API_KEY`); API-key
  use is billed per token. TypeScript SDK `@muse-code/sdk`.
- **SAM parser:** `meta-sam-parser` (Python) / `@meta-sam/parser` (TypeScript).
- **Meta Model Cookbook** (github.com/meta-models/meta-model-cookbook): `07_sam/01_api_basics` is
  the fastest SAM test; `04_muse_code` has "append-only audit log" and "staged approvals"
  recipes that mirror the acta and the approval screen. Cite them in the README if used.

## Smoke tests (day 1, tests 1–5; day 2, tests 6–7)
Scripted in `scripts/smoke/` (`uv run scripts/smoke/s1_access.py`, `s2_structured.py`,
`s3_transcribe.py note.wav`, `s4_baseten_tools.py`, `s5_sam.py photo.png out/`, `s6_image.py`,
`s7_public_data.py`, `s11_mvd_bus.py`, and `s8_donde_queda.py` and `s10_barrios.py`, run with
`functions/venv/bin/python`). They read keys from the environment or `.env` and never print them. Log latency and cost of each in
`notes/NOW.md`.

Results from Uruguay, 2026-10-28:
- 1: 200 in ~4 s. Spark 1.3 reasons by default: a one-line hello used 557 reasoning tokens.
- 2: the strict `Signup` schema parsed on the first try in ~6 s (~1,100 reasoning tokens).
- `extract` (#19, `functions/voice_signup.py`): Voice Transcribe answers JSON
  `{"sessionId", "transcript", "audioDurationMs", "turns"}`; read `transcript`. Spark 1.3 with
  `reasoning_effort: "low"` filled the strict sign-up schema (app ids as enums, `unknown` for
  what wasn't said) right on a 13 s invented note in ~2 s, against ~6 s at the default. The
  whole callable on the emulator: 7 s (transcribe ~4 s, fields ~2 s, upload and delete).
- 10 (`s10_barrios.py [note.wav]`, 2026-11-01): Montevideo's 62 barrios next to the Costa's
  nine. The strict `Signup` with a 72-value barrio enum (71 ids and `unknown`) still parsed on
  every call, at `reasoning_effort: "low"` in 2–5 s (the longer prompt costs about a second over
  the nine-barrio one). Typed: "Barrio Sur" → `barrio-sur`, "Bella Vista" →
  `capurro-bella-vista`, "Malvín Norte" → `malvin-norte`, "Shangrilá" → `shangrila`, "Colón"
  alone → unknown. Voice Transcribe took all 109 keywords: a 7.5 s synthetic note (macOS
  `say`) transcribed in 2.7 s with "Barrio Sur" spelled right, then `barrio-sur`.
- The weekly card (#62, `evals/card/`, 2026-11-01): Spark Open composed three demo rondas'
  cards with the forecast and `compose_card` in 4 turns each, 6–10 s of model time, about 9,500
  tokens in and 1,100 out (reasoning included), about $0.017 a card at $1.25 / $4.25 per million
  (Baseten's listed Spark Open rate, the same as Spark 1.3). Every `compose_card` call fitted
  the catalog and every block passed the gates. Both endpoints accept
  `stream_options: {include_usage: true}` and send the tokens in the last chunk.
- 3: a 10 s synthetic note in 3–5 s. `languageBias: ["Spanish"]` gave the cleaner transcript;
  auto-detect repeated words. Real rioplatense notes are still #21.
- 4: `-1026` called the tool with valid arguments at low and xhigh, plain and streamed, 1–3 s,
  no `<atem:` text; the second turn answered in Spanish **with Markdown bold**, so the gates must
  strip Markdown before a push.
- 5: SAM answers English noun phrases only: "thermos" and "cookies" found, "termo",
  "bizcochos", "mate", "mate gourd", "gourd" and "cup" found nothing; confidence was omitted.
  The mask-at-box cutout came out clean. Muse Image read "rambla" as a Spanish boulevard: name
  Montevideo's coastal promenade in prompts.
- 6 (`s6_image.py cutout.png out/`): generation 13 s, edit with the thermos cutout 12 s, $0.01
  each. The headline came out legible with its accents, but the model added copy nobody asked
  for (a shop list, "Se fía", "Desde 1978"). **Decision: the model draws the picture with no
  text; the flyer's words and the QR are drawn in code**, so every word passes the gates.
- 7 (`s7_public_data.py`): Open-Meteo 0.8 s (72 hours plus sunset); the DNT GTFS zip (2.7 MB,
  8 s) has `stop_times.txt`; Overpass 37 s for 100 places in Ciudad de la Costa, so cache it per
  barrio.
- 8 (`s8_donde_queda.py [photo ...]`, #58): ¿Dónde queda?'s SAM 3.1 phrases ("person", "license
  plate", "house number") and Spark 1.3's `WordsVerdict` through the functions' own code. **Not
  run yet:** written in #58 without access to the key; the tests play back scripted SAM and Spark
  answers. "house number" is the untested phrase: if it finds nothing on a real plaque, try
  "address number" or "door number" in `donde_queda.CONCEPTS`.
- 9 (not written, #57): Spark 1.3's `PlanVerdict` for a shared small plan
  (`shared_plans.SparkPlan`) has only played back scripted answers; it needs a real run with a
  plan at a plaza (allowed), "en mi casa" and a phone number (held) before the pilot. Skipped:
  the key lives in `.env`, which agents don't open.
- 11 (`s11_mvd_bus.py`, #65, 2026-11-02 around 16:40, a Monday): the Intendencia de
  Montevideo's public-transport API (no model; it feeds the organiser's `get_next_buses` and the
  city's last bus). The OAuth2 token (client credentials, `MVD_API_CLIENT_ID` and
  `MVD_API_SECRET_ID`) came in 0.2 s, `Bearer`, **`expires_in` 300 s**, no refresh token, so
  `functions/mvd_buses.py` renews it 30 s early. `/buses/busstops` answered all 4,973 stops
  (0.87 MB) in 0.1 s; the stop nearest Plaza Gomensoro (4078, 26 de Marzo y José Ellauri,
  29 m) had 8 lines in 0.2 s; five `upcomingbuses` calls in a row took 0.2, 0.5, 0.6, 0.7 and
  0.7 s, all 200. **No rate-limit header** came back on any answer, and the burst wasn't refused.
  The ETAs can't all be believed: one bus came "2 s" away at 20.5 km and another at 86 km/h, so
  the code drops any arrival above 50 km/h implied. **The static GTFS needs the token too**
  (403 "Authentication parameters missing" without it, unlike the issue assumed): 16.9 MB in
  1.0 s, version `20261102` (regenerated daily), a time at every one of its 2.2 million
  `stop_times` rows, stop ids equal to the API's `busstopId`, and no `calendar_dates.txt`.
  `scripts/last_bus.py` reads it unchanged in about 5 s.

1. **Access from Uruguay.**
   `curl -s https://api.meta.ai/v1/responses -H "Authorization: Bearer $MODEL_API_KEY" -H "Content-Type: application/json" -d '{"model":"muse-spark-1.3","input":"Decí hola en rioplatense."}'`
   → 200. 402 = no card; 403 = region block.
2. **Spark 1.3 structured.** `client.beta.chat.completions.parse(model="muse-spark-1.3",
   response_format=Signup, messages=[...])` on a typed rioplatense transcript, `Signup` with
   enum `ageBand` and `slots`, list fields, `extra="forbid"` → `.parsed` validates.
3. **Voice Transcribe.** `ffmpeg -i note.m4a -ac 1 -ar 16000 -sample_fmt s16 note.wav`, then
   ```sh
   curl -s https://api.meta.ai/v1/asr/transcribe -H "Authorization: Bearer $MODEL_API_KEY" \
     -F 'request={"model":"muse-voice-transcribe-1.0","audioEncoding":"WAV","mode":"PUSH_TO_TALK","languageBias":["Spanish"],"keywords":["Solymar","El Pinar","truco","termo","bizcochos"]};type=application/json' \
     -F 'audio=@note.wav'
   ```
   → a readable transcript; run once without `languageBias` and compare.
4. **Baseten tools.**
   ```python
   import os, json, time
   from openai import OpenAI
   c = OpenAI(base_url="https://inference.baseten.co/v1", api_key=os.environ["BASETEN_API_KEY"])
   tools = [{"type": "function", "function": {"name": "get_forecast",
     "description": "Hourly rain probability for a barrio on a date",
     "parameters": {"type": "object", "properties": {"barrio": {"type": "string"},
       "date": {"type": "string"}, "reason": {"type": "string"}},
       "required": ["barrio", "date", "reason"], "additionalProperties": False}}}]
   t = time.time()
   r = c.chat.completions.create(model="meta-models/muse-spark-open-1026", tools=tools,
     extra_body={"reasoning_effort": "low"},
     messages=[{"role": "user", "content": "¿Va a llover el miércoles 2026-10-28 de tarde en Solymar? Consultá el pronóstico."}])
   m = r.choices[0].message; print(round(time.time() - t, 1), "s", r.usage)
   print([(tc.function.name, json.loads(tc.function.arguments)) for tc in (m.tool_calls or [])] or ("NO TOOL CALL", m.content))
   ```
   → one `get_forecast` call with parseable arguments and no `<atem:` text. Repeat at `xhigh`
   and with `stream=True`; then send the second turn (the assistant message plus a `tool`
   message `{"p_rain": 80}`) and expect a Spanish answer. If `-1026` returns 404, try
   `meta-models/muse-spark-open`.
5. **SAM 3.1.** In the cookbook's `07_sam/01_api_basics`:
   `python python/01_segment_image.py table.jpg --concept termo --concept thermos --concept "mate gourd" --output out/`
   on a photo with no faces → masks; note which language works; compose one transparent PNG
   cutout with Pillow (mask at its box offset).
6. **Muse Image.** `POST /v1/images/generations` with `{"model":"muse-image-1.0","prompt":"Afiche
   de almacén… texto: \"Hay un mate de más\"","size":"1024x1536","output_format":"png"}`, then
   `/v1/images/edits` with the cutout as `images:[{"image_url":"data:image/png;base64,…"}]` →
   decide whether the text is legible.
7. **Public data.**
   - Open-Meteo: `https://api.open-meteo.com/v1/forecast?latitude=-34.83&longitude=-55.96&hourly=precipitation_probability,precipitation,wind_gusts_10m,weather_code&daily=sunrise,sunset&timezone=America/Montevideo&forecast_days=3`
     (free tier is non-commercial, < 10,000 calls/day; credit it in the README).
   - DNT metropolitan GTFS (2.7 MB, 2026-09-21; covers Canelones ↔ Montevideo lines, not
     Montevideo's urban STM): `curl -L -o gtfs.zip https://catalogodatos.gub.uy/dataset/1d50ccf7-121d-48a7-951e-28a02858d24e/resource/9f44b654-751a-42a4-a481-af91b7c9a2e4/download/gtfs_20260921.zip && unzip -l gtfs.zip`
     → check `stop_times.txt` exists. DNT warns times are under review: the UI says "horario
     publicado".
   - Overpass (send a `User-Agent`, no parallel queries, cache per barrio, never from the phone):
     `curl -A "Ronda-hackathon/0.1 (github.com/Cirorx/ronda)" --data-urlencode 'data=[out:json][timeout:25];(nwr["leisure"~"park|pitch"](-34.87,-56.03,-34.76,-55.83);nwr["amenity"~"community_centre|library"](-34.87,-56.03,-34.76,-55.83););out center 100;' https://overpass-api.de/api/interpreter`
