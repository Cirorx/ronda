# Ronda

**Cinco vecinos, a pocas cuadras, el mismo día todas las semanas. Vos decís "voy"; Ronda organiza el resto.**

*Five neighbours a few blocks from home, the same day every week. You say "voy"; Ronda does the rest.*

Ronda keeps the same small group of neighbours meeting every week around one pretext: mate on the
rambla, truco, fútbol 5. It is built in Ciudad de la Costa and Montevideo, Uruguay, for the
[Meta Global AI Developer Hackathon](https://cerebralvalley.ai/e/meta-ai-developer-hackathon)
(indie track, "Build for Your World"), 27 October – 4 November 2026.

> **Status, 26 October 2026: design only.** The design docs in `docs/` were written before the
> building window opened. Every line of code in this repository is written from
> 27 October 2026 on. Progress is tracked in the [issues](https://github.com/Cirorx/ronda/issues),
> one milestone per day.

## Why

In Uruguay, one in four adults say they feel very lonely, and more than one in three under thirty
[1][2]. Almost a third of homes have just one person in them [3]. Friend apps seat you with new
strangers at every event [4]. Ronda does the opposite: the same faces, close to home, every week,
long enough for neighbours to become people you'd miss.

## How it works

1. **Tell Ronda what you like and when you're free:** one voice note or three taps. No profile, no
   photo.
2. **Get a seat:** an open seat in a ronda nearby, or a new ronda that starts when six neighbours
   want the same thing by a set date. A person approves every group.
3. **The first time, someone waits for you:** a named member, at the spot. After the first meeting
   the group decides in private whether to keep going ("¿seguimos?").
4. **Same faces, same day, same place.** Ronda does the chores: the weekly "¿venís?", the rain
   plan, the bench when someone can't come, and the person you chose writing to you if you miss one.
5. **Then Ronda goes quiet.** The group should outlive the app.

Within 10 blocks (15 in Montevideo) · 5–6 people (10 for fútbol 5) · bring one friend · same slot all season ·
leave or switch without explaining · free: **Ronda nunca pide plata**.

## Meta models in Ronda

Every AI job in Ronda runs on a Meta model, called from the Python functions (`functions/`).
The numbers were measured on the code in this repository, from Uruguay, with each one's date
and number of calls (n); costs use Meta's and Baseten's listed prices. How they were measured
is in [`docs/MODELS.md`](docs/MODELS.md) § Results on the current code.

| Job | Model | Why this model | Measured latency | Cost per call | If it fails |
|---|---|---|---|---|---|
| Hear a spoken sign-up (also the cuaderno's lines and a spoken small plan) | **Muse Voice Transcribe** (`muse-voice-transcribe-1.0`, `POST /asr/transcribe`) | Meta's speech-to-text, biased to Spanish with 114 keywords (every barrio, "truco", "bizcochos"); it got every word of the invented test note (a Mac voice reading a rioplatense sign-up) in two of three calls, and doubled one in the third | 2.3–3.9 s for a 10.5 s note (n = 3, 2026-11-02). Live mode (`wss://…/asr/realtime` through our relay, built and off by default): first words 0.7 s after speaking starts, all of them 0.25 s after stopping (n = 1, 2026-11-02, [`evals/voice`](evals/voice/RESULTS.md)) | $0.0005 for 10.5 s ($0.18 an hour) | Retries 429 and 5xx twice; then "No pudimos leer el audio" and [Prefiero tocar botones], the same sign-up by taps |
| Turn those words into the sign-up's fields | **Muse Spark 1.3** (`muse-spark-1.3`) | The Meta Model API enforces a strict `json_schema`, so name, age band, barrio (one of 71), pretexts, slots and what they bring come back as the app's own ids, or `unknown` | 2.5–4.3 s at `reasoning_effort: low`, about 2,140 tokens in and 430 out; the same fields all three times (n = 3, 2026-11-02) | $0.0045 | The read-back screen, where the person checks and edits every field; on an error, the buttons |
| The organiser agent: the rain check (forecast, sunset, last bus, who's coming, then a proposal to the host), the weekly card, the bench | **Muse Spark Open** (`meta-models/muse-spark-open-1026`) on Baseten | Open weights with tool calling on Baseten; at `reasoning_effort: low` a turn takes about 1.5 s | 1.1–2.5 s a turn. Rain check: 5–6 turns, 8.1–11.0 s of model time (n = 2, 2026-11-02, invented ronda and forecast). Weekly card: 4 turns, 7.5–7.9 s (n = 3, 2026-11-02, [`evals/card`](evals/card/RESULTS.md)), and 6.1 s on the live project (n = 1, 2026-11-02) | Rain check $0.021–0.027; card $0.016–0.018 | Spark 1.3 on the Meta Model API for the rest of the run, on an error or raw `<atem:` text (none of these 6 runs needed it). With no model at all, code goes on alone: the fixed card, the bench's default deadline, no rain proposal |
| Cut the group's things out of the host's photo for the flyer (also find the people, plates and house numbers ¿Dónde queda? blurs) | **SAM 3.1** (`sam-3.1`, Responses API) | Segmentation from a short noun phrase: boxes and masks come back, decoded with `meta-sam-parser` into clean cutouts | 2.6–5.3 s a phrase (n = 8, 2026-11-02); the termo, the mazo and the mates are looked for side by side, beside Muse Image | $0.0025 a phrase; $0.01 for the test photo's 4 | Nothing usable found: "No encontramos el termo, el mazo ni los mates. Probá con otra foto". An error: "Probá de nuevo en un rato". The tear-off flyer (`scripts/flyer.py`) uses no model |
| Paint the flyer's background (also the cuaderno's postcard) | **Muse Image** (`muse-image-1.0`) | Meta's image model; it paints the scene with no people and no text, from a prompt that names the place in full | 17.3–17.9 s (n = 2, 2026-11-02); with SAM beside it, the flyer's whole model step took 17.9 s | $0.01 | Retries 429 and 5xx twice; then "No pudimos hacer el volante. Probá de nuevo en un rato", or the tear-off flyer |

What the code handles about each model:

- **Baseten doesn't enforce the schema for Spark Open.** It accepts each tool's JSON schema
  and passes through whatever the model writes, so every tool call is validated with pydantic
  in code. A call that doesn't fit gets the error back and one more turn: on 2026-11-02 the agent
  wrote an acta line over 200 characters, was told so, and wrote a shorter one. The weekly
  card's blocks are a pydantic catalog too; the model fills typed blocks and code builds the
  screen from them.
- **Spark Open answers in Markdown** (bold, in the first smoke test). Its words are
  Markdown-stripped before the gates read them, and the gates (no emoji, voseo, no money,
  nothing from 21:00 to 09:00) decide whether anything goes out.
- **SAM needs English nouns.** "termo", "mate" and "bizcochos" found nothing; "thermos" and
  "deck of playing cards" did. The code asks in English and tries a second phrase when the
  first finds nothing.
- **Muse Image invents copy.** Asked for a poster's headline, it added a shop list, "Se fía" and
  "Desde 1978". So it paints only the picture, and every word on the flyer and its QR are drawn
  in code (Pillow, segno): no word on a flyer comes from a model.

On the live project, three spoken sign-ups went through on 2026-11-01, taking 11.8–19.1 s in the
function, which downloads the note, transcribes it, reads the fields and deletes it, any cold
start included (n = 3, Cloud Run request logs).

**On the phone, without Meta.** Face detection is the one job that runs on a platform model,
because Meta has no model for it and a photo must not leave the phone with a face in it:
Google's ML Kit (`packages/face_blur`, Android and iOS) finds the faces, detection only, and the
phone pixelates them before upload. Speech recognition is always Voice Transcribe. No
text-to-speech ships in this build: reading a screen aloud is left to the phone's own screen
reader (TalkBack, VoiceOver), through the app's semantics labels.

## Privacy by design: split by sensitivity

- **Needs stay on the phone.** "I can't walk far", "not after dark", "no car" are filters on the
  device. The server only ever learns which seats fit.
- **Voice is understood once.** Sent only after the person accepts short, plain terms; the audio
  is deleted as soon as it's read.
- **Faces are blurred on the phone** before any photo is uploaded. Detection only, never
  recognition.
- **The agent is a bot and says so.** Logistics only, quiet from 21:00 to 09:00, no emoji, and
  every action is written to a log members can read. These are rules in code, not in a prompt.
- **Matching never uses personality.** Only walking distance, time slot, activity and age band.

## Architecture

```
Phone app (Flutter: Android, iOS, web)
  ├─ sign-up by voice or buttons → read-back → profile without needs
  ├─ needs → on-device filters → eligible seat ids
  └─ weekly push: [Voy] [Esta no]
Firebase (São Paulo)
  ├─ Firestore, Storage (audio deleted on success), Hosting (the web app under /app, plain-HTML public pages)
  └─ Python functions: voice extraction · CP-SAT group solver · organiser agent · flyer
Meta Model API (Voice Transcribe, Spark 1.3, SAM 3.1, Muse Image) · Baseten (Muse Spark Open)
Open data: Open-Meteo · DNT bus timetables (GTFS) · OpenStreetMap
```

More in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and [`docs/STACK.md`](docs/STACK.md).

## The nine days

| Day | Date | Build |
|---|---|---|
| 1 | Tue 27 Oct | App skeleton, Firebase, every model answering from Uruguay |
| 2 | Wed 28 Oct | Sign-up by buttons and by voice |
| 3 | Thu 29 Oct | Group solver and the approval screen |
| 4 | Fri 30 Oct | The weekly loop: RSVP, attendance, the bench, ¿seguimos? |
| 5 | Sat 31 Oct | The organiser agent |
| 6 | Sun 1 Nov | Open seats near you, QR landing, the flyer |
| 7 | Mon 2 Nov | First visit and safety |
| 8 | Tue 3 Nov | Real phones, real neighbours |
| 9 | Wed 4 Nov | Video and submission |

Each day is a milestone in the [issues](https://github.com/Cirorx/ronda/milestones), with what proves it's done.

## Docs

- [`docs/PRODUCT.md`](docs/PRODUCT.md): every feature in the build, with the real UI copy
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): components, data model, solver, agent, privacy
- [`docs/STACK.md`](docs/STACK.md): packages, tools and setup
- [`docs/MODELS.md`](docs/MODELS.md): Meta models, partners and smoke tests
- [`docs/DESIGN.md`](docs/DESIGN.md): the look, "the barrio's own paper"
- [`docs/GLOSSARY.md`](docs/GLOSSARY.md): one word per domain concept

## Running it

Setup instructions arrive with the first code on 27 October.

## Data and licences

- Weather: [Open-Meteo](https://open-meteo.com/) (CC BY 4.0)
- Bus timetables: Dirección Nacional de Transporte, metropolitan GTFS, via
  [catalogodatos.gub.uy](https://catalogodatos.gub.uy/) ("Licencia de DAG de Uruguay")
- Places, and the point of each Montevideo barrio (`scripts/montevideo_barrios.py`): ©
  [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors (ODbL)
- All people and data in the mockups and seeds are invented.

## Sources

1. MSP / CIFRA, [*Percepción de la población sobre la salud mental y hábitos de consulta y tratamiento*](https://mediospublicos.uy/wp-content/uploads/2025/10/PERCEPCION-DE-LA-POBLACION-SOBRE-LA-SALUD-MENTAL-Y-HABITOS-DE-CONSULTA-Y-TRATAMIENTO.pdf),
   national telephone survey, n = 803, August 2025: 24% of adults score "very lonely"; 35% under 30.
2. Meta–Gallup, [*The Global State of Social Connections*](https://www.gallup.com/file/analytics/513347/Gallup-Meta-Global%20State%20of%20Social%20Connections%20Report-2023.pdf),
   2023: 25% of people in Uruguay feel very or fairly lonely.
3. INE, [Censo 2023: crecen los hogares unipersonales](https://www.gub.uy/instituto-nacional-estadistica/comunicacion/noticias/censo-2023-crecen-hogares-unipersonales),
   2024: 29.2% of households have one person.
4. Timeleft, [Timeleft Repeat](https://timeleft.com/post/timeleft-repeat-reconnect-with-friends/),
   December 2025: every dinner seats "new faces selected by our algorithm".

## Licence

[MIT](LICENSE)
