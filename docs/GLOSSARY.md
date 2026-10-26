# Glossary

Ronda's domain words. Code uses the **identifier** column (English, except the words that are
the product's own); UI copy uses the **UI (es-419)** column. Use one word per concept everywhere:
issues, docs, code, commit messages.

| Identifier | UI (es-419) | Meaning |
|---|---|---|
| `Ronda` | ronda | A standing group of 5–6 neighbours (10 for fútbol 5) with one pretext, one slot and one place, for a season |
| `Pretext` | actividad | What the ronda does: mate on the rambla, truco, fútbol 5, caminata |
| `Slot` | día y horario | Weekday plus a time band (mañana / tarde / noche) |
| `Barrio` | barrio | The neighbourhood; distance is measured between barrio centroids |
| `AgeBand` | edad ("sesenta y pico") | The only age data Ronda keeps; never a birth date |
| `Brings` | lo que traés | What a member brings or teaches (pan, termo, enseño truco, tengo ganas); how people are known |
| `Needs` | lo que te cuesta | What makes taking part hard (caminar poco, sin escaleras, antes de que oscurezca). Lives only on the phone |
| `Seat` | lugar | One place in a ronda. A seat is *eligible* for a member when it passes their needs filter |
| `Waitlist` | lista de espera | Neighbours waiting for the same barrio × pretext × slot; opens a ronda at the threshold |
| `Threshold` | "somos 4 de 6" | Six on a waitlist by a deadline starts a new ronda |
| `Proposal` | propuesta | The solver's grouping, waiting for the owner's approval, with a rejected alternative |
| `Season` | temporada | The run of weeks a ronda commits to after ¿seguimos? |
| `Seguimos` | ¿seguimos? | The private vote after the first meeting; 4 of 6 yes sets the season |
| `Rsvp` | voy / esta no | The weekly answer. Default is in; "esta no" never asks why |
| `Anfitrion` | anfitrión | The host who opens the meeting this month |
| `Cola` | cola | The co-host who closes; asked first when the anfitrión can't |
| `Bench` | banco | Ordered neighbours who take a seat freed by an "esta no" that week |
| `Despues` | después | The optional 20-minute after-spot on every ronda card |
| `Buddy` | tu persona | The member someone chose to write to them after one missed week |
| `Acta` | lo que hizo el bot | The members' log of every organiser-agent action, with "Algo estuvo mal" |
| `AgentRun` | (admin only) | One run of the organiser agent; its steps are the trace |
| `Gate` | (none) | A rule in code that every outgoing message passes (quiet hours, no emoji, voseo, bot disclosure, no-money line) |
| `Flyer` | afiche | Paper growth: the tear-off flyer and "Hay un mate de más" |
| `Cerca` | cerca tuyo | The public no-login page of open seats and waitlists by barrio |
