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
uploaded and read by `extract` as before, which is also the fallback whenever live fails
(connect, ready, backlog, a dropped socket, a late final) and when `read_transcript` fails.

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
scripted turns shaped like the smoke test's stream, and the first real run is the owner's.

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
`s7_public_data.py`, and `s8_donde_queda.py` and `s10_barrios.py`, run with
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
