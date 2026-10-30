# Ronda

Weekly groups of the same 5–6 neighbours, a few blocks from home, around one pretext (mate on
the rambla, truco, fútbol 5). Flutter app (Android, iOS, web) on Firebase, with Meta models at
runtime, built for the Meta Global AI Developer Hackathon.

## Start of a session
1. Read `notes/NOW.md`. Done when you can say the current state and the next step.
2. On a new machine, also read `notes/HANDOFF.md`, and accept the project plugins
   (`.claude/settings.json`) when Claude Code offers them.
3. Pick one issue: `gh issue list -R Cirorx/ronda --label agent --milestone "<day>"`. Issues
   labelled `human` belong to the owner; if yours depends on an open one, say so and pick
   another.

## Working an issue
1. Read the files the issue names, and the feature's section in `docs/PRODUCT.md`.
2. Load the skills the work touches before writing it:
   - any Dart or Flutter code → `vgv-ai-flutter-plugin:layered-architecture` and `bloc`;
   - theme, colours, spacing, text styles → `material-theming`;
   - a user-facing string → `internationalization`;
   - tests or goldens → `testing`;
   - keys, storage, logging, form input, dependencies → `static-security`;
   - semantics, tap targets, text scale → `accessibility`;
   - the solver or any logic with a clear contract → `mattpocock-skills:tdd`.
3. Build it inside the layers in `docs/STACK.md` § Architecture, with the names in
   `docs/GLOSSARY.md`.
4. Finish **green**: run the `green-gate` skill on every package you touched (analyze, format,
   test, coverage in one passing round, targets in `docs/STACK.md` § Quality bar), and tick every
   box in the issue's "Done when".
5. Commit with `Closes #<n>`, push, and add a line to `notes/NOW.md`.
6. Once your work is on main, run `scripts/prune_worktrees.sh`. It removes every worktree whose
   work is already on main, together with its branch, because each one holds gigabytes of
   build output. It keeps the ones with uncommitted changes, locked ones, and any where nothing
   was ever committed, since that may be a fresh worktree whose agent hasn't written anything
   yet.

## End of a session
Update `notes/NOW.md`: done, half-done, next step, and anything learned (model quirks, API
paths, latency, cost). Done when a fresh session could continue from `notes/NOW.md` alone.

## Local-only notes
`notes/` is git-ignored by this repo and is its own local git repo with no remote. It holds
`NOW.md`, `HANDOFF.md`, `PLAN.md`, `HACKATHON.md`, `DEMO.md`, `PILOT.md`, `DEVTOOLS.md` and
`planilla/`. Anything personal or operational (local paths, accounts, schedules, people, pilot
details) goes there; tracked files stay free of it, because this repo is public. Commit notes
changes inside `notes/` (`git -C notes commit`); there is nothing to push.

## Rules that shape the code
**Hackathon** (summary in `notes/HACKATHON.md`, local):
- Code starts on **2026-10-27**; the window closes **2026-11-04 21:00 ET (23:00 Uruguay)**.
  Write everything fresh in the window: no code from earlier projects, Farolito included.
- The repo is public. Commit only invented demo data, labelled as such. Keys live in `.env` and
  Cloud Functions config; member data, phone numbers, voice notes and photos stay out of git.
- Every AI job Meta offers runs on Meta: Voice Transcribe, Muse Spark 1.3, Muse Spark Open
  (Baseten), SAM 3.1, Muse Image. A platform model is used only for a job Meta has no model for,
  only on the phone, and is named in the README: ML Kit face detection and the phone's own
  text-to-speech. Speech recognition is always Voice Transcribe.
- Data with rights only: Open-Meteo (CC BY 4.0), DNT GTFS, OpenStreetMap (ODbL, attributed).
- Matching uses slot, distance, pretext and age band. Ronda is neighbourhood infrastructure:
  no health framing, no personality, nothing political.

**Product** (settled with the owner; change only with them):
- People are known by first name, age band and what they bring. One weekly card, no feed,
  photos of people or map pins.
- **Split by sensitivity:** needs stay on the phone as seat filters and the server gets
  eligible seat ids; voice is sent only after the person accepts the terms (by continuing past
  the welcome screen, which links them) and is deleted once read; faces are
  pixelated on the phone before upload (detection only).
- The organiser agent says it is a program and does logistics. Every outgoing message passes
  the **gates** in code: 09:00–21:00 only, no emoji, voseo, no money, one routine push a week.
  "Ronda nunca pide plata" lives in the terms and on the flyers only; a message that mentions
  money is held.
- Copy is rioplatense voseo ("¿Venís?"). Every string ships in en and es-419.

## Docs: read when
- `docs/STACK.md` — before adding a package, a layer, a test or any setup; holds the
  architecture, quality bar, security rules and the gotchas assistants get wrong.
- `docs/GLOSSARY.md` — before naming a class, field, collection or UI string.
- `docs/PRODUCT.md` — before building a feature; real UI copy included.
- `docs/ARCHITECTURE.md` — before touching Firestore, Storage, Functions, the solver or the agent.
- `docs/MODELS.md` — before calling a Meta model or Baseten; has the smoke tests.
- `docs/DESIGN.md` — before building a screen; the screen canvas is linked in `notes/HANDOFF.md` (local).
- `notes/PLAN.md` (local) — to see what a day must prove; the issues carry the same blocks.
- `notes/DEMO.md` (local) — when work feeds the video.
- `notes/HANDOFF.md` (local) — decisions made and still open, where everything lives.
- `notes/PILOT.md` (local) — when work touches real members: dates, consent, data deletion.
- `notes/DEVTOOLS.md` (local) — running Claude Code on Meta models, credits budget, questions for Discord.
