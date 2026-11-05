# Ronda

Weekly groups of the same neighbours (they open with 2 and fill to 6), a few blocks from home,
around one pretext (mate on the rambla, truco, fútbol 5). Flutter app (Android, iOS, web) on
Firebase, with Meta models at runtime, built for the Meta Global AI Developer Hackathon.

These are the rules coding agents follow in this repo. A `CLAUDE.local.md` next to this file,
if present, adds machine-specific workflow and is never committed.

## Working an issue
1. Pick an issue labelled `agent` (`gh issue list -R Cirorx/ronda --label agent`). Issues
   labelled `human` are for a person; if yours depends on an open one, say so and pick another.
2. Read the files the issue names, and the feature's section in `docs/PRODUCT.md`.
3. Load the skills the work touches before writing it (the plugins are enabled in
   `.claude/settings.json`):
   - any Dart or Flutter code → `vgv-ai-flutter-plugin:layered-architecture` and `bloc`;
   - theme, colours, spacing, text styles → `material-theming`;
   - a user-facing string → `internationalization`;
   - tests or goldens → `testing`;
   - keys, storage, logging, form input, dependencies → `static-security`;
   - semantics, tap targets, text scale → `accessibility`;
   - the solver or any logic with a clear contract → `mattpocock-skills:tdd`.
4. Build it inside the layers in `docs/STACK.md` § Architecture, with the names in
   `docs/GLOSSARY.md`.
5. Finish **green**: run the `green-gate` skill on every package you touched (analyze, format,
   test, coverage in one passing round, targets in `docs/STACK.md` § Quality bar), and tick every
   box in the issue's "Done when".
6. Land it through a pull request. `main` is protected: no force-push, no deletion, and the CI
   jobs build, functions, solver, scripts, rules and spell-check must pass. Push a branch, open
   the PR with `gh pr create` (a conventional-commit title, since the semantic-pull-request
   check reads it; `Closes #<n>` in the body), wait for the checks, then
   `gh pr merge --squash --delete-branch`. Write real commit messages: what changed and why.
7. Stop anything your work left running (Firebase emulators and their function workers,
   `flutter run`, `flutter test` and their browsers) before you call it done.

## Rules that shape the code
**Hackathon:**
- Built in the window **2026-10-27 to 2026-11-04 21:00 ET**, all code written fresh in it.
- The repo is public. Commit only invented demo data, labelled as such. Keys live in `.env` and
  Cloud Functions config; member data, phone numbers, voice notes and photos stay out of git.
- Every AI job Meta offers runs on Meta: Voice Transcribe, Muse Spark 1.3, Muse Spark Open
  (Baseten), SAM 3.1, Muse Image. A platform model is used only for a job Meta has no model for,
  only on the phone, and is named in the README: ML Kit face detection and the phone's own
  text-to-speech. Speech recognition is always Voice Transcribe.
- Data with rights only: Open-Meteo (CC BY 4.0), DNT GTFS, the Intendencia de Montevideo's
  public-transport API (free with an account; no licence stated, named in the README anyway),
  OpenStreetMap (ODbL, attributed).
- Matching uses slot, distance, pretext and age band. Ronda is neighbourhood infrastructure:
  no health framing, no personality, nothing political.

**Product** (settled decisions; change them only with the maintainer):
- People are known by first name, age band and what they bring. One weekly card, no feed,
  photos of people or map pins.
- **Split by sensitivity:** needs stay on the phone as seat filters and the server gets
  eligible seat ids; voice is sent only after the person accepts the terms (by continuing past
  the welcome screen, which links them) and is deleted once read; faces are
  pixelated on the phone before upload (detection only).
- The organiser agent says it is a program and does logistics. Every outgoing message passes
  the **gates** in code: 09:00–21:00 only, no emoji, voseo, no money, one routine push a week.
  "Ronda nunca pide plata" lives in the terms only; a message that mentions money is held.
- Copy is rioplatense voseo ("¿Venís?"). Every string ships in en and es-419.

## Docs: read when
- `docs/STACK.md`: before adding a package, a layer, a test or any setup; holds the
  architecture, quality bar, security rules and the gotchas assistants get wrong.
- `docs/GLOSSARY.md`: before naming a class, field, collection or UI string.
- `docs/PRODUCT.md`: before building a feature; real UI copy included.
- `docs/ARCHITECTURE.md`: before touching Firestore, Storage, Functions, the solver or the agent.
- `docs/MODELS.md`: before calling a Meta model or Baseten; has the smoke tests.
- `docs/DESIGN.md`: before building a screen.
