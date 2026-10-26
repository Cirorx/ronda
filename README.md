# Ronda

**Cinco vecinos, a pocas cuadras, el mismo día todas las semanas. Vos decís "voy"; Ronda organiza el resto.**

*Five neighbours a few blocks from home, the same day every week. You say "voy"; Ronda does the rest.*

Ronda keeps the same small group of neighbours meeting every week around one pretext: mate on the
rambla, truco, fútbol 5. It is built in Ciudad de la Costa, Uruguay, for the
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

Within 10 blocks · 5–6 people (10 for fútbol 5) · bring one friend · same slot all season ·
leave or switch without explaining · free: **Ronda nunca pide plata**.

## Meta models in the product

| Model | Where it runs | What it does in Ronda |
|---|---|---|
| Muse Voice Transcribe | Meta Model API | Turns a sign-up voice note in rioplatense Spanish into text |
| Muse Spark 1.3 | Meta Model API | Turns that text into fields the member checks and edits |
| Muse Spark Open | Baseten | The organiser agent: forecast, sunset, last bus, RSVPs, the bench, proposals to the host |
| SAM 3.1 | Meta Model API | Cuts the group's things (termo, mate, mazo) out of a photo for a flyer |
| Muse Image | Meta Model API | Lays out the "Hay un mate de más" flyer for the almacén board |

## Privacy by design: split by sensitivity

- **Needs stay on the phone.** "I can't walk far", "not after dark", "no car" are filters on the
  device. The server only ever learns which seats fit.
- **Voice is understood once.** A consent screen first; the audio is deleted as soon as it's read.
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
  ├─ Firestore, Storage (audio deleted on success), Hosting (plain-HTML public pages)
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
- Places: © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors (ODbL)
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
