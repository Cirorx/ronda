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
  │               in code), answer_move (the host's pick after the rain check)
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
- `rondas/{id}`: pretext, barrio, slot {day, time}, place {name, landmark, lat, lng} (public
  places only), size, status (forming | active | paused | ended), hosts {anfitrion, cola,
  rotatesOn}, despues {kind: none | place | home, label, address?, hostOk}
  (members-only read; the address is deleted at the end of the day and never sent in a push),
  season {start, end} (the ISO dates of its first and last meeting, set by the ¿seguimos? close,
  which also makes the ronda `active`), openSeatFromWeek: 4,
  rsvpLead {daysBefore 1–6, hour 9–20}? (when the RSVP push goes out, Montevideo time; missing
  or out of range reads as two days before at 19:00, so a Saturday ronda takes Friday with
  `{daysBefore: 1, hour: 19}`).
- `rondas/{id}/members/{uid}`: brings, state (active | paused | left), joinedAt, pausedUntil?
  (the first meeting date they are back for, `YYYY-MM-DD`; "Pausar 2 semanas"), leftAt? (a
  "no" to ¿seguimos? leaves at its close; the document and `users/{uid}/rondas/{id}` stay, so
  their phone still finds the ronda and shows "Gracias por venir.").
- Rules: a ronda and its members list are read by that ronda's members only (a
  `members/{uid}` document for the caller); no client writes either.
- `users/{uid}/rondas/{rondaId}`: joinedAt. How a member's phone finds their ronda (a query on
  `rondas` can't pass the members-only rule); written and deleted with the ronda by
  `approve_proposal`, read by that member only.
- `rondas/{id}/weeks/{isoWeek}`: date, placeOverride?, rsvp {uid: yes | no}, rsvpSentAt,
  attendance {uid: bool}, plan {uid: item}. The id is the meeting's ISO week (`2026-W44`), even
  when the push goes out the week before. Read by no client: members never read the raw `rsvp`
  map (rules test: `rules/rsvp.test.js`). `rsvpSentAt` is set in a transaction before the push
  goes out, which makes it once per ronda and week.
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
    admin (the bench and threshold flows are #48).
- `waitlists/{barrio_pretext_slot}`: entries[{uid, at}], threshold: 6, deadline.
- `bench/{rondaId}`: ordered uids.
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
- `agent_runs/{runId}/steps/{n}` (`001`, `002`…): n, ts, kind and what it carries: `model`
  (model, latencyMs, toolCalls, content), `tool` (tool, argsSummary, reason, resultSummary,
  status ok | refused | invalid, latencyMs, model), `message` (toRole, toName, title, text, gate
  allowed | blocked, gateName, gateReason, releaseAt, outcome sent | held | unreachable |
  skipped), `host` (the pick, or the deadline passing), `note`, `stop` (why). Admin-only (the
  rules match `agent_runs/{document=**}`); rendered live at `/admin/programa`.
- `rondas/{id}/moves/{isoWeek}` (#49, `functions/organiser/moves.py`): the rain proposal to the
  host: week, date, hour, hostUid, hostName, hostFallback, title, body, runId, forecast
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
- Gates in code (not prompt): quiet hours 21:00–09:00, bot disclosure, no emoji, voseo, one
  routine push a week, public places only for the ronda itself (the host may set a home
  for the después). ("Ronda nunca pide plata" is in the terms and on the
  flyers, not in messages.)

Built in #49 (`functions/organiser/`, `functions/rain.py`; `assign_hosts`, `prompt_buddy`,
`offer_bench_seat` and "Ronda se calla" are #50):
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
  checker's limits are in `text.py`), one routine message a week (the RSVP push is that ronda's
  routine message; a host's proposal and a host-decided change are not routine), public places
  (a place a message sends people to must be `public`, and no "en lo de" or address in the
  words). `log_acta` text passes the word gates. A held message is a `message` step with
  outcome `held` ("Frenado") and the reason; a sent one `sent` ("Salió").
- **The rain decision** (`rain.run_rain_check`, job `rain_check`): the evening before each
  meeting, 18:00 to 21:00 in Montevideo, once per ronda and week. The agent reads the forecast
  for the meeting's two hours (a slot's band starts at 10, 16 or 19 until a host sets an hour),
  and when the worst hour reaches 60% it checks the sunset, the last bus (a tear-off flyer's
  stored `lastBus` for the barrio, so `scripts/last_bus.py` runs once per flyer, not per week)
  and the counts, then `propose_move`s: a covered place of the barrio, another day up to three
  days later, and always "Vamos igual", each with the exact member message written in code. The
  gates run before anything is written; a held proposal leaves no move. The host is
  `hosts.anfitrion` while active, else the first active member, flagged `hostFallback`.
- **The host's pick** (`answer_move {rondaId, week, choice}`): the move's host only, before 21:00;
  claimed in a transaction, so one push per member and a second call sends nothing; the members
  get the option's message through the gates (kind `change`). Without a pick, the next hourly run
  marks it expired: "queda como está". The host's screen is `/lluvia/{rondaId}/{week}`, which the
  web push links to; Android draws the push but a tap opens Mi ronda, not the screen, until
  `PushClient` routes taps.
- **Screens:** `/admin/programa` (the live trace, "Correr el chequeo de lluvia" and "Probar a las
  22:00", which runs it at 22:00 today so the gates hold what it would send); `/acta/{rondaId}`
  (members, linked from Mi ronda); `/lluvia/{rondaId}/{week}` (the host).

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
