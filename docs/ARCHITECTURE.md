# Architecture

## Thesis: split by sensitivity

- Voices are understood once by Voice Transcribe + Muse Spark, only after the person accepts
  the terms by continuing past the welcome screen (Ley 18.331 art. 23: sending voice to the US
  is an international transfer, so the tap is the express consent and is recorded). Nothing is
  kept after extraction.
- Needs (a bad knee, no car, not after dark) stay on the phone as seat filters. The server
  receives only eligible seat ids. (Mobility on a server is arguably health data, art. 4E/18.)
- Faces are blurred on the phone (ML Kit face detection; never recognition, art. 18 BIS)
  before any photo is uploaded. SAM 3.1 and Muse Image see blurred photos only.
- The organiser agent reasons on Muse Spark Open (Baseten). The server plans the barrio from
  seat ids, RSVPs and counts.

## Components

```
Phone (Flutter: iOS, Android, web)
  ├─ welcome (terms accepted by continuing) → onboarding (buttons | voice) → upload audio
  ├─ needs → local filters → eligible seat ids → Firestore
  ├─ face blur (ML Kit) → upload blurred photo
  └─ FCM pushes in; RSVP / attendance / reports out
Firebase (southamerica-east1; Auth itself runs in the US; Spark plan, so where Functions and Storage live is #35)
  ├─ Firestore: users, rondas, weeks, waitlists, proposals, reports, acta, agent_runs
  ├─ Storage: audio + blurred photos; deleted on success, hourly sweeper, lifecycle as backstop
  ├─ Functions (Python 3.13, 2nd gen):
  │    callables  extract (Transcribe → Spark), propose_groups (CP-SAT, admin), rsvp,
  │               run_job(name, now) (admin, for tests and the demo)
  │    scheduled  one hourly dispatcher → run_<job>(now); hourly audio sweeper
  │    agent, flyer (SAM → cutouts → Muse Image → text + QR in code)
  ├─ Hosting: Flutter web app under /app; plain-HTML /cerca and /f/{id}
  └─ FCM → APNs (iOS only with the Apple Developer Program)
Meta Model API: Voice Transcribe, Spark 1.3, SAM 3.1, Muse Image
Baseten: Muse Spark Open (agent)
Public data: Open-Meteo, DNT GTFS, OpenStreetMap (cached per barrio)
```

Keys live only in Functions config; the app never holds Meta or Baseten keys. Every callable
requires `auth != null` and is pinned to `southamerica-east1` on both sides.

## Code boundaries (keep the exit cheap)
- Flutter talks to Firestore only through repositories (`UserRepository`, `RondaRepository`, …);
  widgets and cubits never import `cloud_firestore`.
- The solver is a pure Python package: JSON in, JSON out, no Firebase imports. The function is
  a thin wrapper.
- Every scheduled job is a plain `run_<job>(now)`: the dispatcher, the admin `run_job` callable
  and the tests all call the same function with an injected clock.
- Extraction is a callable the app awaits after upload (synchronous read-back), not a Storage
  trigger.

## Data model (Firestore, draft)

- `users/{uid}`: firstName, ageBand, barrio, slots[], pretexts[], brings[], plusOneUid?,
  buddyUid?, terms {version, acceptedAt}, createdAt. Sign-in is Google: no phone number is held. **Never:** address, cédula, birth
  date, lives-alone, nationality, mood, needs.
- `users/{uid}/private/eligible`: seatIds[] (written by the phone; read by the solver only).
- `users/{uid}/tokens/{token}`: platform (android | ios | web), updatedAt. The sender builds a
  different payload per platform (`docs/STACK.md` § Push).
- Rules reject any user write that carries a `needs`, mood or audio field.
- `rondas/{id}`: pretext, barrio, slot {day, time}, place {name, landmark, lat, lng} (public
  places only), size, status (forming | active | paused | ended), hosts {anfitrion, cola,
  rotatesOn}, despues {kind: none | place | home, label} (members-only read; a label, never an
  address), season {start, end}, openSeatFromWeek: 4.
- `rondas/{id}/members/{uid}`: brings, state (active | paused | left), joinedAt.
- `rondas/{id}/weeks/{isoWeek}`: date, placeOverride?, rsvp {uid: yes | no}, attendance
  {uid: bool}, plan {uid: item}, seguimos {uid: yes | no} (week 1 only).
- `waitlists/{barrio_pretext_slot}`: entries[{uid, at}], threshold: 6, deadline.
- `bench/{rondaId}`: ordered uids.
- `avoid/{pairId}`: uidA, uidB (report-apart; read by the solver only).
- `reports/{id}`: reporter, reported, rondaId, tag, text (minimal), status.
- `acta/{rondaId}/entries/{id}`: tool, summary, decidedBy (agent | host), ts.
- `agent_runs/{runId}/steps/{n}`: ts, tool, argsSummary, reason, resultSummary, latencyMs, model,
  gate (allowed | blocked). Admin-only; rendered live as the agent trace.
- `proposals/{id}`: groups, checks, rejected alternative + broken rules, status (pending |
  approved). Admin-only; nothing reaches members before approval.
- `flyers/{id}`: spotId, stopId, rondaIds[], scans.
- Public view for Cerca tuyo: `public_seats/{id}` (barrio, pretext, time band, age band, seats
  left, waiting count). No names.

## Solver (Python, OR-Tools CP-SAT)

- Runs per season and on refill (ronda at 4) or merge (ronda at 3), never weekly.
- Hard: a person only in seats from their eligible set; slot and pretext match; distance by
  barrio centroid under ~10 blocks; avoid pairs never together.
- Soft (weighted): ≥ 2 per age band; size by activity; +1 pair together; ≤ 1 +1 pair per ronda;
  cross-age truco partners; open a nearby ronda before seating far.
- Output: proposals + the best rejected alternative with the rule it broke (shown to Ciro).

## Organiser agent

- Runs on the weekly schedule (Mon plan, Tue 19:00 RSVP, Wed 18:00 quorum/rain check, day-
  before spot + last bus, Fri buddy prompt) and on events (an "esta no" → bench).
- Tools: `get_forecast` (Open-Meteo), `get_sunset`, `get_last_bus` (DNT GTFS), `count_rsvps`,
  `propose_move` (to the host), `send_member_push` (gated), `assign_hosts`, `prompt_buddy`,
  `offer_bench_seat`, `log_acta`. Every tool call is idempotent, takes a required `reason`, and is
  logged to the acta.
- Two humans in the loop: Ciro approves groups; the host decides moves; the buddy writes the
  check-in in their own words.
- Gates in code (not prompt): quiet hours 21:00–09:00, bot disclosure, no emoji, voseo, one
  routine push a week, public places only for the ronda itself (the host may set a home
  for the después). ("Ronda nunca pide plata" is in the terms and on the
  flyers, not in messages.)

## Data sources and licences

| Source | Licence | Use |
|---|---|---|
| Open-Meteo | CC BY 4.0 data; free tier non-commercial | Hourly rain, gusts, sunset |
| DNT metropolitan GTFS (catalogodatos.gub.uy; Canelones ↔ Montevideo lines, not urban STM) | DAG UY | Last bus ("horario publicado") |
| OpenStreetMap via Overpass | ODbL, attribution | Places (plazas, clubs, canchas) |
| Meta HDX population maps | CC BY | After the hackathon: flyer placement |
| INUMET forecast JSON | No licence granted | **Not used** until permission |

## Where data lives (Ley 18.331 art. 23)
- Firestore, Storage and Functions sit in São Paulo. **Brazil is not on URCDP's adequate list**
  (Res. 23/021 and 63/023, which do list EU/EEA members, Argentina and US organisations on the
  Data Privacy Framework). Firebase Auth keeps the sign-in identity (Google account id, email) in the US (Google claims DPF).
  Voice and photos go to Meta in the US.
- So the terms name all three in one line: "Tus datos se guardan en Brasil; el audio lo procesa
  Meta y el inicio de sesión Google, en EE. UU." They are accepted by continuing past the welcome
  screen, which links them. Ask the URCDP before onboarding pilot members.
- Needs and mood never leave the phone, so no sensitive data crosses a border.

## Privacy and safety checklist (must hold in the demo)
- Terms accepted (version and time recorded) before any audio or photo leaves the phone.
- No needs, no mood, no audio, no unblurred faces in Firestore or Storage after 24 h.
- Payers or institutions only ever see totals with cells ≥ 10 (after the hackathon).
- Helpline in settings: Línea de Prevención del Suicidio 0800 0767 / *0767, 911. Not in the pitch.
