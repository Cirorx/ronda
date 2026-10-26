# Ronda

Weekly groups of the same 5–6 neighbours, a few blocks from home, around one pretext (mate on
the rambla, truco, fútbol 5). Built for the Meta Global AI Developer Hackathon, indie track,
"Build for Your World". Flutter app + web, Firebase, Meta models.

## Start of every session

1. Read `docs/NOW.md`: where things stand, the next step, and the last session's notes.
2. Read `docs/HANDOFF.md` once per new machine.
3. Pick work from the GitHub issues (`gh issue list -R Cirorx/ronda --label agent --milestone "<day>"`).
   Each `agent` issue says what to read, the work, "done when" and what it depends on; `human`
   issues are the owner's only. Close the issue from the commit.
4. Before writing code for a feature, read its section in `docs/PRODUCT.md`.

## End of every session

Update `docs/NOW.md`: what was done, what is half-done, the next step, anything learned
(model quirks, API paths, costs). This file is how the next session picks up without loss.

## Hackathon rules that shape the code (full summary in `docs/HACKATHON.md`)

- Building window **2026-10-27 → 2026-11-04 21:00 ET (23:00 Uruguay)**. Only code written in
  the window counts, and the demo may show only that. These docs predate the window; the
  README must say so. Never import code written before 10-27.
- The repo is **public**. Never commit pilot members' data, phone numbers, voice notes or
  photos; demo data is invented and labelled as such. Secrets live in `.env` / Firebase config,
  never in git.
- The product must use Meta models at runtime (Voice Transcribe, Muse Spark, Muse Spark Open
  via Baseten, SAM 3.1, Muse Image). No other vendor's model inside the product.
- Only data we have rights to: Open-Meteo (CC BY 4.0), DNT GTFS (DAG UY), OpenStreetMap
  (ODbL, attribution), Meta HDX population maps (CC BY). Not INUMET's forecast JSON.
- Anti-projects: no mental-health framing, no personality analysis, nothing political.
  Matching uses only slot, distance, pretext and age band.

## Product rules (from the research; don't relitigate without the owner)

- No feed, no profile photos, no map with pins. People are known by first name, age band and
  what they bring.
- Nothing about mood is stored server-side (Ley 18.331 art. 4E/18). Needs (a bad knee, no
  car) stay on the phone as seat filters; the server receives eligible seat ids only.
- Voice and faces leaving Uruguay need an explicit consent screen (art. 23). Faces are
  blurred on the phone before upload (detection only, never recognition: art. 18 BIS).
- The bot says it is a bot, does logistics only, never writes between 21:00 and 09:00,
  never uses emoji or icebreakers, never fills a quiet chat. These are code gates, not
  prompt instructions.
- "Ronda nunca pide plata" appears in every member-facing message.
- Copy is rioplatense voseo ("¿Venís?"), never "tú". UI ships en + es-419.

## Docs

- `docs/HANDOFF.md` — start here: state, decisions, open questions, links.
- `docs/NOW.md` — live session log and next step.
- `docs/PLAN.md` — the 9-day plan with "done when" per day.
- `docs/PRODUCT.md` — the offer and the spec of every feature in the build.
- `docs/ARCHITECTURE.md` — components, data model, agent tools, solver, privacy.
- `docs/DESIGN.md` — UI direction, tokens, type, principles, Flutter theme setup.
- `docs/STACK.md` — Flutter packages and versions, Python requirements, tools, push design,
  native checklist, gotchas AI assistants get wrong.
- `docs/DEMO.md` — the 3-minute video script, shot list, claims to check, X cut.
- `docs/MODELS.md` — Meta models, ids, prices, partners, dev-tool setup, day-1 smoke tests.
- `docs/HACKATHON.md` — rules, judging, prizes, schedule.
- `docs/planilla/index.html` — source of the feature planilla artifact (mockups).
