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
  ├─ welcome (terms accepted by continuing) → buttons: questions and payoff signed out, then
  │    sign-in | voice: sign-in, then the recording → upload audio
  ├─ needs → local filters → eligible seat ids → Firestore
  ├─ face blur (ML Kit) → upload blurred photo
  └─ FCM pushes in; RSVP / attendance / reports out
Firebase (southamerica-east1; Auth itself runs in the US; Blaze plan, phone sign-in off)
  ├─ Firestore: users, rondas, weeks, waitlists, proposals, reports, acta, agent_runs
  ├─ Storage: audio + blurred photos; deleted on success, hourly sweeper, lifecycle as backstop
  ├─ Functions (Python 3.13, 2nd gen):
  │    callables  extract (Transcribe → Spark), propose_groups (CP-SAT, admin), answer_rsvp,
  │               answer_seguimos, run_job(name, now?, force?) (admin, for tests and the
  │               demo), make_mate_flyer (SAM → cutouts, Muse Image background → text + QR
  │               in code), answer_move (the host's pick after the rain check),
  │               ronda_candidates, add_to_ronda, pilot_numbers (admin, the pilot's /admin),
  │               ronda_setups and set_ronda_setup (admin: place, hour and hosts),
  │               record_attendance (a host's or the admin's "Vino" / "No vino"),
  │               answer_bench_offer ([Lo tomo] / [Esta vez no]), answer_waitlist (the
  │               pick after a waiting list didn't fill)
  │    triggers   bench_on_answer (an RSVP answer changed) and bench_on_offer (an offer
  │               was answered) run that ronda's bench at once
  │    scheduled  one dispatcher on the hour in Montevideo (`dispatch`) → run_<job>(db, now)
  │               for every job in `jobs.JOBS`; hourly audio sweeper (`sweep_audio`
  │               deletes `audio/` objects older than 1 h); hourly Cerca counts (`refresh_cerca`,
  │               until the dispatcher adopts `run_refresh_cerca`)
  │    http       flyer_landing (public: counts a flyer's scan, answers /f/{id})
  │    agent      functions/organiser/ (loop, tools, gates, trace) run by the `rain_check` job
  │               (functions/rain.py) inside `dispatch` and `run_job`
  ├─ Hosting: Flutter web app under /app; plain-HTML Cerca tuyo at / and /f/{id}
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
- Every scheduled job is a plain `run_<job>(db, now)` that is safe to run again: the dispatcher,
  the admin `run_job` callable and the tests all call the same function with an injected clock
  (`functions/jobs.py`). A job sends nothing itself: it builds FCM HTTP v1 messages as dicts and
  `fcm.send` delivers them, skipping every one under the functions emulator.
- Extraction is a callable the app awaits after upload (synchronous read-back), not a Storage
  trigger.

## Data model (Firestore, draft)

- `users/{uid}`: firstName, ageBand, barrio, slots[], pretexts[], brings[], plusOneUid?,
  buddyUid?, terms {version, acceptedAt}, createdAt. Sign-in is Google: no phone number is held. **Never:** address, cédula, birth
  date, lives-alone, nationality, mood, needs.
- `users/{uid}/private/eligible`: seatIds[], updatedAt (written by the phone; read by the solver only).
- `seat_facts/{seatId}` (decided in #20): what the server publishes for the phone's filter, one
  document per seat id `{barrio}_{pretext}_{slot}`, read by any signed-in member, written by the
  admin SDK only. Fields: barrio, pretext, slot, `blocksFrom {barrioId: blocks}`, `hasStairs`,
  `endsAfterDark`, `needsCar`, updatedAt.
  - **Walk distance is per member, so the phone computes it.** It depends on the member's barrio
    and the seat's, so the document carries `blocksFrom`: the haversine walk from every barrio's
    centroid to the seat's (a block is 100 m, as in the solver), and the phone reads its own
    barrio's entry: near ≤ 5 blocks, medium ≤ 10, far beyond (`WalkDistance.forMember` in
    `needs_repository`). A barrio missing from the table reads as far. The server already holds
    the member's barrio in the profile, so this sends nothing new.
  - `hasStairs` and `needsCar` describe the place, so they are false until a host sets one; the
    server republishes the document then, and phones recompute.
  - `endsAfterDark` is per seat: the slot's end against that week's Open-Meteo sunset.
  - The phone writes `users/{uid}/private/eligible` = exactly `{seatIds, updatedAt}` (rules check
    the keys, a list of at most 1000 strings shaped `{barrio}_{pretext}_{slot}`, and
    `updatedAt == request.time`). No client reads it back, not even its owner or the admin.
  - When: on "Está bien, guardalo" (for answers given signed out, right after sign-in), after
    the needs are saved on the phone and before the profile. The phone filters by needs only (pretext and slot are the solver's match). If
    reading the seats or writing the ids fails, the save fails and no profile is written, so
    the person retries from the read-back and nobody reaches the tabs without eligible ids.
  - Known limits: the solver's hard `withinTenBlocks` already drops far seats, so "caminar mucho"
    changes no grouping today and only keeps far ids from leaving the phone. And the server holds
    both the facts it published and the ids that came back, so it could infer a need from which
    ids are missing (all evening seats gone → "volver de noche"). The need itself is never sent.
  - Demo data: `data/demo/invented_seat_facts.json` (invented: 14 hand-made seats, two with a
    place an invented host has set) over seats generated the same way for every barrio ×
    pretext × slot the demo people pick, loaded by `scripts/seed.py` (§ Demo data).
- `users/{uid}/tokens/{token}`: platform (android | ios | web), updatedAt (server time). Written
  and deleted by the owner only, never read by a client (rules test: `rules/tokens.test.js`); the
  phone deletes its own on sign-out, before the auth state changes. The
  sender builds a different payload per platform (`docs/STACK.md` § Push).
- Rules accept on `users/{uid}` only the fields above (typed: `ageBand` one of the bands,
  `firstName` 1–30 characters, `terms` exactly `{version, acceptedAt}`, `slots`, `pretexts` and
  `brings` lists of id strings), so any write carrying a `needs`, mood, audio or address field is
  rejected, at the top level or inside a list element (rules test: `rules/users.test.js`). The
  `terms` write comes first and creates the document; the profile lands on it when onboarding is
  saved.
- Before sign-in nothing is written: the buttons path is answered signed out, so the accepted
  terms (`held.terms`: version, acceptedAt) and the answers (`held.answers`: the profile fields
  as ids) wait on the phone in `device_store`, through `profile_repository`; the needs are in
  `needs_repository` as always. Right after sign-in the app writes the held terms, then saves
  the held answers as on "Está bien, guardalo" (needs filter, eligible ids, profile), and clears
  both once a profile exists, including one saved before on another phone.
- `rondas/{id}`: pretext, barrio, slot {day, time, hour?}, place {name, landmark?, lat?, lng?}
  (public places only), size, status (forming | active | paused | ended), hosts {anfitrion,
  cola, anfitrionName, colaName, rotatesOn?}, setupAt, despues {kind: none | place | home, label, address?, hostOk}
  (members-only read; the address is deleted at the end of the day and never sent in a push),
  season {start, end} (the ISO dates of its first and last meeting, set by the ¿seguimos? close,
  which also makes the ronda `active`), openSeatFromWeek: 4,
  rsvpLead {daysBefore 1–6, hour 9–20}? (when the RSVP push goes out, Montevideo time; missing
  or out of range reads as two days before at 19:00, so a Saturday ronda takes Friday with
  `{daysBefore: 1, hour: 19}`).
- Place, hour and hosts (built in #47, `functions/hosts.py`): `approve_proposal` writes none of
  them, and nothing invents them. The admin sets all three at once on `/admin/rondas`
  (`set_ronda_setup {rondaId, place: {name, landmark?} | null, hour: "16:00" | null, anfitrion,
  cola}`, admin only; an empty value removes it; `ronda_setups` lists every ronda that still
  meets with its members' first names and latest roll, since the admin reads no ronda,
  member or profile from a client).
  - `slot.hour` starts inside the band with an hour of it left (09:00–11:00, 14:00–17:00,
    19:00–20:00; `rsvp.hour_in_band`); one outside reads as none.
  - The place's words pass the organiser's word gates (no emoji, voseo, nothing that looks
    like a home or an address: `failed-precondition`), since every message naming it passes
    them later. The sheet sets no `lat`/`lng` (no map pins): the rain check reads the barrio's
    centroid.
  - Hosts are members of the ronda and two different people; their first names ride along so
    members' cards say "Abre Mirta. Cierra Jorge." without reading a profile. The monthly
    rotation (`rotatesOn`) is not built.
  - Until they are set: the card says "Lugar y hora a confirmar" (or just the missing one), the
    RSVP push's body opens with the same words and its title names the band ("Jueves a la
    tarde"), the rain check reads the whole band, and there is no host.
- `rondas/{id}/members/{uid}`: brings, state (active | paused | left), joinedAt, pausedUntil?
  (the first meeting date they are back for, `YYYY-MM-DD`; "Pausar 2 semanas"), leftAt? (a
  "no" to ¿seguimos? leaves at its close; the document and `users/{uid}/rondas/{id}` stay, so
  their phone still finds the ronda and shows "Gracias por venir.").
- Rules: a ronda and its members list are read by that ronda's members only (a
  `members/{uid}` document for the caller); no client writes either.
- `users/{uid}/rondas/{rondaId}`: joinedAt. How a member's phone finds their ronda (a query on
  `rondas` can't pass the members-only rule); written and deleted with the ronda by
  `approve_proposal`, read by that member only.
- `rondas/{id}/weeks/{isoWeek}`: date, placeOverride?, dateOverride?, rsvp {uid: yes | no},
  rsvpSentAt, attendance {uid: bool}, plan {uid: item}. The id is the meeting's ISO week
  (`2026-W44`), even when the push goes out the week before. No member reads it, not even a
  host: the raw `rsvp` map and who came stay off members' phones (rules tests:
  `rules/rsvp.test.js`, `rules/hosts.test.js`). The admin reads it (since #47), for the
  attendance numbers, so the admin also sees the raw `rsvp`. `rsvpSentAt` is set in a
  transaction before the push goes out, which makes it once per ronda and week.
- Attendance (built in #47, `functions/attendance.py`): "¿Quién vino hoy?".
  - The `attendance_ask` job (`run_attendance_ask(db, now)`): on meeting day (the rain move's
    `dateOverride` when there is one), an hour into the meeting and 20:00 at the latest (an
    hour before the band ends while there is no hour), it writes the roll and pushes the ask
    to the anfitrión, else the cola (each only while in for the meeting and not having said
    "esta no"), once per ronda and week; held 21:00–09:00 like every push. Push: `data.type:
    attendance` with rondaId and week, drawn plain (a tap opens Mi ronda on Android, where the
    host's card links the roll); web opens `/asistencia/{rondaId}/{week}`. With no host to ask,
    the roll is written with nobody asked: the server holds no admin uid (the claim lives on
    the Auth token), so the admin finds it on `/admin/rondas`.
  - `rondas/{id}/rolls/{isoWeek}`: the host's roll: week, date, line, hour, people [{uid,
    firstName}] (the members in for that meeting, by first name; who said "esta no" stays on,
    so the order gives nobody away), marks {uid: bool} (the host's copy of the record),
    askedUid, askedRole (anfitrion | cola | ""), askedAt, updatedAt. `get` by the ronda's
    anfitrión and cola and the admin, never listed (rules test: `rules/hosts.test.js`).
  - `record_attendance {rondaId, week, uid, came}`: the ronda's anfitrión or cola (still in the
    ronda), the host the roll was sent to, or the admin; for someone on the roll; until six
    days after the meeting. Writes `weeks/{w}.attendance.{uid}` and the roll's mark in one
    transaction. Members read neither.
- `rondas/{id}/views/week` (built in #45, `functions/rsvp.py`): "who's coming" to the upcoming
  meeting, read by the ronda's members: week, date, going [{uid, firstName, brings}] (the
  yeses, by first name), noCount, unansweredCount (only counts for the rest; a member paused over
  the meeting counts as "no puede"), updatedAt. Rewritten with every answer, and by the RSVP job
  when the meeting it shows has passed.
- `rondas/{id}/answers/{uid}`: week, answer (yes | no), at. The member's own last answer, read by
  that member only, so a "no" never shows to the others.
- The weekly RSVP (#45): `answer_rsvp {rondaId, answer, week?, pauseWeeks?}` (members of that
  ronda only) writes the raw answer, the view and the member's own answer in one transaction;
  `week`, sent from the push, must still be the upcoming meeting's, so an old notification can't
  answer next week. The `rsvp_push` job (`run_rsvp_push(db, now)`) sends each open ronda's push
  once a week at its `rsvpLead`, catching up on a later run until the meeting day, never from
  21:00 to 09:00 Montevideo (held and tried on the next run), and only to members who are in,
  not paused and haven't answered. `run_job {name: 'rsvp_push', force: true}` (the admin's
  "Mandarlo ahora") skips the lead time and the meeting-day limit, never the gate or the
  once-a-week mark.
- ¿Seguimos? (#9, built in #46, `functions/seguimos.py`):
  - `rondas/{id}/private/seguimos`: askedAt, firstMeeting, asked [uids], answers {uid: yes |
    no}, choices {uid: join | wait}, then closedAt, outcome (season | didntFill), meeting; or
    {skipped: "late", skippedAt} when the ask came too late. Read by no client, not even the
    admin (rules test: `rules/seguimos.test.js`).
  - `rondas/{id}/seguimos/{uid}`: the member's own question and what came of it, read by that
    member only: status (open | closed), askedAt, answer?, answeredAt?, then closedAt, outcome
    (season | gracias | didntFill), alternatives [{rondaId, line, pretext, barrio, slot,
    placesLeft, next}] (after a no: up to two; below the floor: the nearest), floor?, wait
    {until, start}?, choice? (join | wait).
  - `seguimos_counts/{rondaId}`: what /admin shows, read by the admin claim only: line (es-419),
    status (open | season | didntFill), asked, yes, no, unanswered, choices {join, wait},
    season?, askedAt, closedAt?, updatedAt. Counts only.
  - The ask: the `seguimos_ask` job (`run_seguimos_ask(db, now)`) asks every active member of a
    ronda with no season at 20:00 Montevideo on the day of its first meeting (the next day for
    an evening slot), once per ronda. The first meeting is the earliest `weeks/` date (which
    survives a later change of `slot.day`), or the slot's first day after approval when there is
    none. It catches up on later runs, held 21:00–09:00, but never once the RSVP push for a
    later meeting has gone out (the ronda is marked `skipped: late`). Push: `data.type:
    seguimos`, drawn with [Sí] [No].
  - The answer: `answer_seguimos {rondaId, answer: yes | no}` (members who were asked, while it
    is open; it can change until the close), or after a close below the floor `{rondaId,
    choice: join | wait}`. Writes the private answers, the member's own document and the counts
    in one transaction.
  - The close runs inside the next RSVP push for that ronda (`rsvp.run_rsvp_push` →
    `seguimos.close`), with the ronda read at send time. Yeses from members still in ≥ the
    pretext's floor (`SizeRule.floor`: 4; fútbol 8): `season` is set for `SEASON_WEEKS` (4)
    meetings from the one the push is for, the ronda becomes `active`, and the RSVP body opens
    with "Seguimos los jueves, hasta el jueves 26/11. Nadie sabe qué contestó cada uno."
    (members the RSVP skips get those words alone). Each "no" leaves (`state: left`) and gets
    "Gracias por venir." with up to two open rondas within the solver's ten blocks that have
    places, same pretext first. Below the floor: no season, `status` unchanged, and everyone
    still in gets the didn't-fill words instead of the RSVP; their pick is recorded for the
    admin. The waiting list's own didn't-fill (#48) is below.
- The bench (built in #48 with #50's `offer_bench_seat`, `functions/bench.py`): a seat an "esta
  no" freed (a "no", or a pause over the meeting without an answer) is offered to one person at
  a time.
  - Who is on it and in what order is code's (`bench_order`): sign-ups with a profile who count
    (`demo_users.counts`), seated in no ronda that still meets, who picked the ronda's pretext
    and slot, live within the solver's ten blocks, have the ronda's seat id among their
    `private/eligible` ids (the needs filter), and hold no other pending offer nor a seat taken
    elsewhere that day; by profile `createdAt`, then blocks, then uid.
  - `rondas/{id}/bench/{isoWeek}` (server only): offers [{offerId, uid, firstName, status}] in
    the order they went out, skipped, summary {at, by, sentAt, done}, notes, lockedUntil
    (a five-minute lease: one run per ronda at a time), updatedAt. Only a run holding the lease
    writes it.
  - `users/{uid}/offers/{offerId}` (`{rondaId}_{isoWeek}_{nn}`): rondaId, week, date, pretext,
    slot {day, time}, hour, placeName, placeLandmark, deadline, status (pending | taken |
    declined | expired | withdrawn), createdAt, answeredAt | closedAt. Read (get and list) by
    that person only (rules test: `rules/bench.test.js`). Its status lives here alone and
    changes in transactions, so an answer and a run never overwrite each other.
  - `answer_bench_offer {offerId, take}` (`bench.answer`): the person's own pending offer before
    its deadline; taking writes `weeks/{w}.guests.{uid} = {firstName, brings, offerId, at}` and
    rewrites `views/week` in the same transaction. It writes no trace: the next run reads the
    answer and records it as a person's step.
  - A guest is not a member: `rsvp.week_view` lists guests in `going` with `guest: true`, and
    `attendance.people` puts them on the roll, while `counted()` callers (¿seguimos?, sizes,
    Cerca) never see them and `pilot_numbers` counts attendance of members only.
  - When: the `bench` job runs hourly in `dispatch` and by `run_job`; the two Firestore
    triggers run one ronda's bench right after an RSVP answer changes or an offer is answered.
    Deadlines fall on the hour, so the hourly run moves on when one passes. Nothing is offered
    or told 21:00–09:00 (the run waits for the 09:00 one), nor less than two hours before the
    meeting.
- The waiting list (built in #48, `functions/waitlists.py`; the `waitlists` job, hourly):
  - `waitlists/{seatId}` (server only): barrio, pretext, slot, threshold (`SizeRule.cap`),
    entries [{uid, at}] (sign-ups seated nowhere with that seat id among their eligible ids,
    longest waiting first), round {deadline, start} (to a Sunday; the slot's day the week
    after), last {deadline, start, outcome full | didntFill, closedAt}, choices {uid: join |
    wait}, updatedAt. Past its deadline a round at the threshold rolls one week (the admin's
    solver and approval make the ronda); one short of it closes as didn't-fill and the next
    round is two weeks on, with the choices reset.
  - `waiting/{uid}`: the person's card, read by that person only: the list with the most
    entries (then the earliest deadline): seatId, barrio, pretext, slot, count, threshold,
    deadline, start, status (open | full | didntFill | joined), alternatives (one nearby ronda
    with places, `seguimos.alternatives`), choice?, updatedAt. Deleted when they wait nowhere.
  - `answer_waitlist {choice: join | wait}` while the card says didntFill; `join` needs the
    nearby ronda, which the admin then adds them to ("Sumar a esta ronda").
- `avoid/{pairId}`: uidA, uidB (report-apart; read by the solver only).
- `reports/{id}`: reporter, reported, rondaId, tag, text (minimal), status.
- `acta/{rondaId}/entries/{runId}-{k}` (built in #49, `functions/organiser/trace.py`): week, ts,
  tool, summary (es-419, written in code like the pushes; the model's own words only through
  `log_acta`, after the word gates), decidedBy (agent | host), runId. Read by that ronda's
  members as "Lo que hizo el programa" (`/acta/{rondaId}`); one line per tool call and per send.
- `acta/{rondaId}/flags/{uid}`: exactly `{week, at}` (`at == request.time`), written by a member
  of that ronda for themselves when they tap [Algo estuvo mal]; read by the admin only, who sees
  the count on the trace (rules test: `rules/organiser.test.js`).
- `agent_runs/{runId}`: job, rondaId, week, startedAt, endedAt, status (running | done | capped
  | stopped | failed), model, forced, note (the model's last words, Markdown stripped),
  stepCount, actaCount. The rain check's run is `{rondaId}_{week}_rain` (claimed in a transaction,
  so once a week; a failed run is claimed again on the next hour); a forced run adds
  the time it ran for (`_20261104T2200`).
- `agent_runs/{runId}/steps/{n}` (`001`, `002`…): n, ts, kind, by (who decided it: `code`,
  `model` or `person`; `organiser.trace.AUTHORS`) and what it carries: `model`
  (model, latencyMs, toolCalls, content), `tool` (tool, argsSummary, reason, resultSummary,
  status ok | refused | invalid, latencyMs, model), `message` (toRole, toName, title, text, gate
  allowed | blocked, gateName, gateReason, releaseAt, outcome sent | held | unreachable |
  skipped), `host` (the pick, or the deadline passing), `answer` (a person's answer to an
  offer), `note`, `stop` (why). Admin-only (the
  rules match `agent_runs/{document=**}`); rendered live at `/admin/programa`.
- `rondas/{id}/moves/{isoWeek}` (#49, `functions/organiser/moves.py`): the rain proposal to the
  host: week, date, hour ("16:00" or null), hostUid, hostName, hostFallback, title, body, runId, forecast
  {rainProbability, rainMm, gustsKmh}, options [{id covered | postpone | asIs, label, message,
  placeId?, placeName?, date?}], recipients, deadline (21:00 the evening before), status
  (pending | decided | expired), createdAt; once decided choice, decidedAt, sent, held. `get`
  by its `hostUid` only, never listed. A pick writes `weeks/{w}.placeOverride {placeId, name}`
  or `weeks/{w}.dateOverride` (`YYYY-MM-DD`); the Mi ronda card and `views/week` don't read
  either yet, so members learn the change from the push.
- `places/{id}`: covered public places the organiser may offer when it rains: name (with its
  article, "el Salón Comunal de El Pinar"), barrios[], covered, kind (`public`). Read by the
  server only. The demo set is `data/demo/invented_places.json`; the real project has none until
  the owner adds them.
- `users/{uid}/private/agent`: what the gates remember of a person: introducedAt (their first
  organiser message, which carries "Soy un programa") and routine {isoWeek: at}. No client
  reads it.
- `proposals/{id}` (built in #25, `functions/proposals.py`): status (pending | approved),
  solverStatus, groups[{id (seat id), barrio, pretext, slot, checks, members[{uid, firstName,
  ageBand, distanceBlocks, plusOneInGroup?}]}], unseated[uids], rejectedAlternative {brokenRule,
  reason (es-419), reasons} or null, createdAt, createdBy; once approved also rondaIds,
  approvedAt, approvedBy. `plusOneInGroup` is set only when the member's +1 also signed up.
  `unseatedPeople [{uid, firstName, barrio, slots, pretexts}]` names the unseated for /admin
  (#55; older proposals lack it); `unseated` stays the uids `scripts/reset.py` reads.
  Read by the admin claim only (`request.auth.token.admin == true`), written only by the
  callables, so nothing reaches members before approval (rules test: `rules/`).
  - `propose_groups` (admin only, 2 GiB, 4 vCPU, max 1 instance, no min instances) reads
    `users`, `users/{uid}/private/eligible` and `avoid`, keeps people with a profile in a known
    barrio and eligible ids, solves, joins first names and writes a pending proposal. The
    barrio centroids are the solver's demo table (`ronda_solver.demo.DEMO_BARRIOS`).
  - `approve_proposal {proposalId}` writes one `rondas/{autoId}` (seatId, pretext, barrio,
    slot {day, time}, size, status forming, openSeatFromWeek 4, createdAt; no place, hosts or
    season yet) and `rondas/{id}/members/{uid}` (brings, state active, joinedAt) per group in one
    batch, with `users/{uid}/rondas/{id}` for each member, then marks the proposal approved. `{proposalId, undo: true}` deletes them and puts it
    back to pending ([Deshacer]; nothing has been sent yet: the Tuesday push is the agent's).
    One batch holds 500 writes, enough for about 240 members.
  - The admin claim is set by `scripts/set_admin.py <email>` after the owner signs in once.
- "Sumar a esta ronda" (#55, `functions/ronda_members.py`), both admin only:
  - `ronda_candidates {rondaId}`: the ronda's line, its members' first names, seats taken
    (active and paused) and its cap (`size_rule(pretext).cap`), and every sign-up who counts
    (`demo_users.counts`) with a profile in a known barrio and not sitting in it: first name,
    age band, barrio, slots, pretexts, blocks, the ronda they sit in (`rondaId`, `rondaLine`)
    and `warnings`: `slot` / `pretext` they didn't pick, `barrio` beyond the solver's ten
    blocks, `seat` (the seat id isn't in their `private/eligible`; which need, nobody knows).
  - `add_to_ronda {rondaId, uid, move?}` refuses an invented `demo-` uid where it doesn't count
    (`failed-precondition`), a ronda that doesn't meet (`failed-precondition`), a sign-up
    without such a profile (`not-found`), a member already in it (`already-exists`), a full
    ronda (`resource-exhausted`), and someone sitting in another ronda that still meets unless
    `move: true` (`failed-precondition`). In one transaction it writes
    `rondas/{id}/members/{uid}` `{brings, state: active, joinedAt}` (re-adding a `left`
    member drops `leftAt`) and `users/{uid}/rondas/{id}`, sets the ronda's `size` to its
    seated count, rewrites `views/week` with `rsvp.week_view` (the new member is sin contestar:
    nothing goes into `weeks/{w}.rsvp`), and rewrites the approved proposal that made the ronda
    (its group gains them, `unseated` / `unseatedPeople` lose them, every `plusOneInGroup`
    again). A move marks the old membership `left` with `leftAt`, deletes that
    `users/{uid}/rondas` link (the phone follows the lowest id), and rewrites the old ronda's
    `size`, view and proposal group; a link to a ronda they left or that ended is deleted.
    Nothing is sent: a member added after the week's RSVP push answers from the card, and an
    open ¿seguimos? didn't ask them.
- `pilot_numbers` (#55, `functions/pilot_numbers.py`): the /admin numbers panel, counted on
  call and never stored, demo uids left out where they don't count and a ronda with no member
  who counts left out whole. Sign-ups with a profile of `users` documents; of those, seated in
  a ronda that still meets; per ronda its members of the cap and per `weeks/{isoWeek}` the RSVP
  as `rsvp.week_view` counts it (among members joined by the meeting's date and not left
  before it; a pause reads from the member's current `pausedUntil`), `attendance {uid: bool}`
  as came of marked (`null` while unmarked), came back (of who came to the first marked
  meeting, who came to the next marked one), and `seguimos_counts/{id}`. JSON only: counts,
  ids and ISO dates.
- `cerca/{barrio}` (built in #43, `functions/cerca_tuyo.py`): what Cerca tuyo shows, one
  document per barrio, counts only. `rondas[{pretext, slot, ageFrom, ageTo (null for 80+),
  members, cap, waiting}]` for each forming or active ronda (`members` counts active and paused
  members, `cap` is the pretext's largest ronda, 6 or 10; `waiting` counts sign-ups in that barrio
  who picked its pretext and slot and sit in no ronda), `waiting[{pretext, count}]` the same
  sign-ups by pretext, and updatedAt. No uid, name or place. Anyone may `get` one, signed in or
  not; nobody lists or writes them from a client (rules test: `rules/public.test.js`). The app's
  onboarding payoff reads one signed out, the waiting counts only (`ronda_repository`'s
  `cerca`, 8 s timeout). The
  hourly `refresh_cerca` rewrites all of them with `run_refresh_cerca(db, now)`; once #28 writes
  `waitlists`, their entries should feed the waiting counts too.
- `flyers/{id}`: one collection for both printed flyers, told apart by `kind` (a document with
  none is a `tearOff`, as flyers made before #44 are). Both QRs open `/f/{id}` on the web app's
  domain, and the id is eight of `[a-z0-9]` (`scripts/flyer.py`'s alphabet) for both.
  - `tearOff` (built in #43, `scripts/flyer.py`, which writes `kind: "tearOff"`): label (the
    spot, for the admin's scans per spot; never public), pretext, slot, barrio, nearBarrios[] (the barrios whose centroid is within
    the solver's ten blocks of where it hangs, its own first), stop {id, name}, lastBus {weekday,
    saturday, sunday: {time, estimated, route, published {time, stop}} or null}, scans, createdAt,
    lastScanAt. No coordinates: the spot picks the barrio, the near barrios and the stop when the
    flyer is made, and is dropped. The last bus is computed then, once, from the DNT timetable
    (`scripts/last_bus.py`): the feed gives times at only a few stops of each trip, mostly its ends,
    so a stop between two of them gets an estimate along the route, marked `estimated`, with the
    published time it comes from. Closed to every client.
  - `mate` ("Un mate de más", built in #44, `functions/mate_flyer.py`): rondaId, barrio (the
    ronda's, for the landing), createdBy (the host's uid), imagePath (`flyers/{uid}/{id}.jpg` in
    Storage), scans, createdAt, lastScanAt. Written only by the `make_mate_flyer` callable; read
    (`get`, never listed) by `createdBy` and by that ronda's `hosts.anfitrion` / `hosts.cola`
    (rules test: `rules/flyers.test.js`).
    - The phone pixelates every face (`packages/face_blur`) and uploads the JPEG to
      `flyer_photos/{uid}/{photoId}.jpg` (owner-only create, `image/jpeg`, ≤ 3 MB, no client
      read). `make_mate_flyer {rondaId, photoPath}` checks the path is the caller's and that they
      host the ronda (a host once `hosts` is set; until then any active member, since
      `approve_proposal` writes rondas without hosts), re-saves the photo without EXIF, then side
      by side runs SAM 3.1 for the termo, the mazo and the mates (English phrases, one per
      request, masks decoded with `meta-sam-parser`) and Muse Image for a background with no
      people and no text. Pillow draws the words and the segno QR, and the flyer is stored at
      `flyers/{uid}/{id}.jpg`, readable by its owner only. The photo is deleted whatever happens;
      Storage's lifecycle rule on `flyer_photos/` (1 day) is the backstop. Nothing found to cut
      out answers `failed-precondition`, and the app asks for another photo.
  - `flyer_landing` answers `/api/f/{id}` (a Hosting rewrite) for both kinds: a POST counts the
    scan with an increment, a GET only reads; both return the flyer's `kind` and the `cerca`
    rows of the near barrios and the last bus (a `mate` flyer: its ronda's barrio, no bus),
    never the label, the stop id, the ronda, the host or the image, with `Cache-Control:
    no-store`. The page posts once per tab and reads on reload; link previews run no script, so
    they count nothing.

### Demo data (emulators)

`scripts/reset.py` restores the golden-path state each demo beat is recorded from;
`scripts/seed.py 30` (or `200`) writes a set on top. Commands in `docs/STACK.md` § Native and
project checklist. Everything seeded is invented:

- The people come from the solver's generator (`ronda_solver.demo`, fixed seed): the 30 set is
  exactly `solver/fixtures/invented_demo_30.json`. `scripts/demo_data.py` adds a first name and
  brings per uid, deterministically. Every uid starts with `demo-`: the rules leave no room for a
  label field on `users/{uid}`, so the id is the label.
- Documents: `seat_facts/{seatId}` (144: 9 barrios × 4 pretexts × the 4 demo slots);
  `places/demo-*` (5 invented covered public places, `data/demo/invented_places.json`);
  `users/{uid}` with the profile, `plusOneUid` on whoever brings a +1 (as the generator gives
  it) and the accepted terms; `users/{uid}/private/eligible` = `{seatIds, updatedAt}`; and
  `avoid/{uidA}_{uidB}` per report-apart pair, uids in order (one pair in the 30 set). Needs are
  never seeded. The 30 set is 210 documents.
- Every timestamp is one fixed demo moment (`DEMO_TIME`), never the server's, so two resets leave
  identical documents (Firestore's own create and update times aside).
- Reset deletes every Auth account and document of the project through the emulators' clear
  endpoints, then seeds the 30 set. The person on the phone has no account, so onboarding shows.
  A new collection is one builder in `BUILDERS` (`scripts/demo_data.py`).
- On the real project (`reset.py --project ronda-uy`) it deletes only what the `demo-` uids and
  the demo seat ids identify, then seeds again; real members and Auth are never touched, so a
  signed-in phone keeps its account and profile. That includes what was built from demo people
  alone: a `proposals/{id}` whose groups and unseated are all `demo-` uids, and a `rondas/{id}`
  whose members all are, with everything under it (members, weeks, views, answers,
  private). A proposal or ronda naming any other uid, or a ronda with no members, is kept and
  printed for the owner to decide. It stops before deleting anything if a demo seat fact differs
  from the invented one.
- On the real project the demo sign-ups count for nothing (`functions/demo_users.py`): Cerca's
  counts (`run_refresh_cerca`) and the solver's input (`propose_groups`) skip every uid that
  starts with `demo-`, and every avoid pair naming one. A ronda whose members are all `demo-`
  uids is left out of Cerca; a mixed one counts its real members only. They count as anyone
  under the Functions emulator (`FUNCTIONS_EMULATOR=true`) and on a `demo-*` project
  (`GCLOUD_PROJECT`), so demos and tests have people; a project with no id counts as real. The
  `demo-` test is written once in `functions/demo_users.py` and once in `scripts/reset.py`
  (`is_demo_uid`); `scripts/tests/test_demo_uids.py` checks that the two agree.

## Solver (Python, OR-Tools CP-SAT)

Built in `solver/` (#23): pure Python, JSON in and out, no Firebase imports. The contract,
weights and limits are in `solver/README.md`; every rule name and number is in
`solver/ronda_solver/rules.py`.

- Runs per season and on refill (ronda at 4) or merge (ronda at 3), never weekly. Only the season
  run is built: there is no input for existing rondas yet.
- Candidate rondas are barrio × pretext × slot, one per key. A seat id is that key,
  `{barrio}_{pretext}_{slot}`, so the phone can send eligible ids before any ronda exists.
- Hard: a person only in seats from their eligible set; slot and pretext match; distance by
  barrio centroid ≤ 10 blocks; avoid pairs never together; one ronda each; a ronda opens only
  within its size bounds (fútbol 8–10, every other pretext 4–6).
- Soft (weighted): nobody the only one of their age group (under 30, 30–59, 60+); shortfall from
  the target size (fútbol 10, truco 6, others 5); +1 pair together; ≤ 1 +1 pair per ronda;
  cross-age truco partners (kept by #9); open a nearby ronda before seating far.
- Output: proposals + the next-best rejected alternative with the rules it breaks, structured
  and as an es-419 sentence (shown to Ciro); a checker re-verifies every hard rule on any output.
  A hand-built grouping is explained the same way, hard rules through a CP-SAT core.
- Time: 8 s for the solve, then 2 s for the alternative. 200 invented people: optimal in 6–9 s
  on 8 cores; on 1–4 cores the limit stops it 1–5 seats short of optimal, so size the function
  in #25 by cores.

## Organiser agent

- Runs on the weekly schedule (Mon plan, Tue 19:00 RSVP, Wed 18:00 quorum/rain check, day-
  before spot + last bus, Fri buddy prompt) and on events (an "esta no" → bench).
- Tools: `get_forecast` (Open-Meteo), `get_sunset`, `get_last_bus` (DNT GTFS), `count_rsvps`,
  `propose_move` (to the host), `send_member_push` (gated), `assign_hosts`, `prompt_buddy`,
  `offer_bench_seat`, `log_acta`. Every tool call is idempotent, takes a required `reason`, and is
  logged to the acta.
- Two humans in the loop: Ciro approves groups; the host decides moves; the buddy writes the
  check-in in their own words.
- Gates in code (not prompt): quiet hours 21:00–09:00, bot disclosure, no emoji, voseo, no
  money, one routine push a week, public places only for the ronda itself (the host may set a
  home for the después). ("Ronda nunca pide plata" is in the terms and on the flyers; a
  message that mentions money is held.)

Built in #49 (`functions/organiser/`, `functions/rain.py`; `assign_hosts`, `prompt_buddy`,
and "Ronda se calla" are #50; `offer_bench_seat` is built in #48, below):
- **Model:** `organiser.model.ChatModel` speaks OpenAI-compatible Chat Completions, streamed,
  with `reasoning_effort: low`, to Muse Spark Open on Baseten (`meta-models/muse-spark-open-1026`);
  `FallbackModel` moves to `muse-spark-1.3` on the Meta Model API for the rest of a run when Spark
  Open errors or leaks raw `<atem:` text. Keys come from the function's secrets
  (`BASETEN_API_KEY`, `MODEL_API_KEY`, bound to `dispatch` and `run_job`) and the client is built
  only when a ronda is due.
- **Loop** (`organiser.agent.run_agent`): at most 12 model turns. Every tool call is validated
  with pydantic (`extra="forbid"`, every field required, `""` for none, so the schemas carry no
  `anyOf`); a call that doesn't fit gets the error as its result and one more turn, and a second
  bad turn stops the run. The model's words are Markdown-stripped before they are kept.
- **What the model sees:** the pretext, the meeting's day, hour and place name, the time, and the
  covered places' ids and names; counts from `count_rsvps`. No member's name, uid or address.
- **Gates** (`organiser.gates`, `organiser.text`), in order, on every message: quiet hours (held
  with `releaseAt`, the next 09:00), disclosure (the outbox adds "Hola, X. Soy un programa…" to a
  person's first organiser message and the gate checks it), no emoji, voseo (tú-only words; the
  checker's limits are in `text.py`), no money (plata, pesos, "$", pagar, cuota, transferencia,
  Mercado Pago, colecta…; "Río de la Plata" passes; held as "menciona plata («…»)"), one
  routine message a week (the RSVP push is that ronda's
  routine message; a host's proposal and a host-decided change are not routine), public places
  (a place a message sends people to must be `public`, and no "en lo de" or address in the
  words). `log_acta` text passes the word gates. A held message is a `message` step with
  outcome `held` ("Frenado") and the reason; a sent one `sent` ("Salió").
- **The rain decision** (`rain.run_rain_check`, job `rain_check`): the evening before each
  meeting, 18:00 to 21:00 in Montevideo, once per ronda and week. The agent reads the forecast
  for the meeting's two hours from `slot.hour` (three when it starts at the half hour; the
  whole band while there is no hour, and then the messages say "a la tarde", never a guessed
  hour),
  and when the worst hour reaches 60% it checks the sunset, the last bus (a tear-off flyer's
  stored `lastBus` for the barrio, so `scripts/last_bus.py` runs once per flyer, not per week)
  and the counts, then `propose_move`s: a covered place of the barrio, another day up to three
  days later, and always "Vamos igual", each with the exact member message written in code. The
  gates run before anything is written; a held proposal leaves no move. The host is
  `hosts.anfitrion` while active, else `hosts.cola`, else the first active member, flagged
  `hostFallback`.
- **The host's pick** (`answer_move {rondaId, week, choice}`): the move's host only, before 21:00;
  claimed in a transaction, so one push per member and a second call sends nothing; the members
  get the option's message through the gates (kind `change`). Without a pick, the next hourly run
  marks it expired: "queda como está". The host's screen is `/lluvia/{rondaId}/{week}`, which the
  web push links to; Android draws the push but a tap opens Mi ronda, not the screen, until
  `PushClient` routes taps.
- **Screens:** `/admin/programa` (the live trace, "Correr el chequeo de lluvia" and "Probar a las
  22:00", which runs it at 22:00 today so the gates hold what it would send); `/acta/{rondaId}`
  (members, linked from Mi ronda); `/lluvia/{rondaId}/{week}` (the host).

- **The bench's split** (#48, `functions/bench.py`): each step of
  `agent_runs/{rondaId}_{isoWeek}_bench` (one run per meeting, its steps added as the bench
  moves) says who decided it.
  - Code: who is on the bench and in what order, the needs filter, the gates, one offer per
    freed seat, expiry and "Esta vez no" (the next person), withdrawing an offer when a member
    says "voy" again, and the `demo-` exclusion on the real project. Code also writes every word
    the person and the host read.
  - The model (the same `run_agent` loop and `FallbackModel`, built with a 20 s timeout, at most
    8 turns): it reads `get_forecast`, `get_sunset`, `get_last_bus` and `count_rsvps`, then
    `offer_bench_seat(deadline)` or `skip_offer`, and `tell_host(at)` for when the host's
    summary goes. It is told counts and times, never a name. A deadline outside the hours code
    allows is refused with the allowed range, for a retry.
  - Without a decision (no model, an error, a timeout, the turn cap, or no call) code offers
    with `default_deadline` and a `note` step says why; without a chosen time, code sends the
    host's summary once the bench settles. The summary goes to the anfitrión, else the cola,
    never a stand-in.

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
