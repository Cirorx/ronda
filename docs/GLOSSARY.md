# Glossary

Ronda's domain words. Code uses the **identifier** column (English, except the words that are
the product's own); UI copy uses the **UI (es-419)** column. Use one word per concept everywhere:
issues, docs, code, commit messages.

| Identifier | UI (es-419) | Meaning |
|---|---|---|
| `Ronda` | ronda | A standing group of 5–6 neighbours (10 for fútbol 5) with one pretext, one slot and one place, for a season |
| `Pretext` | actividad | What the ronda does: mate on the rambla, truco, fútbol 5, caminata |
| `Slot` | día y horario | Weekday plus a time band (mañana / tarde / noche), and once the admin sets it the hour it starts (`slot.hour`, "16:00") |
| `Barrio` | barrio | The neighbourhood; distance is measured between barrio centroids |
| `AgeBand` | edad ("sesenta y pico") | The only age data Ronda keeps; never a birth date. Values: `18-29`, `30-39`, `40-49`, `50-59`, `60-69`, `70-79`, `80+` |
| `Brings` | lo que traés | What a member brings or teaches (pan, termo, enseño truco, tengo ganas); how people are known |
| `Needs` | lo que te complica ir | What makes taking part hard (caminar mucho, subir escaleras, volver de noche, no tengo auto). Lives only on the phone |
| `Seat` | lugar | One place in a ronda. A seat is *eligible* for a member when it passes their needs filter. Its id is the ronda's key, `{barrio}_{pretext}_{slot}` |
| `Need` | (one item of lo que te complica ir) | `walkALot`, `climbStairs`, `returnAfterDark`, `noCar`; stored by these names on the phone |
| `SeatFacts` | (none) | What the filter knows about a seat: `walkDistance`, `hasStairs`, `endsAfterDark`, `needsCar` |
| `WalkDistance` | a pocas cuadras | `near` ≤ 5 blocks, `medium` ≤ 10, `far` beyond; "caminar mucho" drops far |
| `Waitlist` | lista de espera | Neighbours seated nowhere waiting for the same seat id (barrio × pretext × slot) that passes their needs filter; opens a ronda at the threshold |
| `Threshold` | "hay 4 anotados y hacen falta 6" | The pretext's largest ronda (6; fútbol 10) on a waitlist by its deadline, a Sunday; the ronda would start on its slot's day the week after |
| `Proposal` | propuesta | The solver's grouping, waiting for the owner's approval, with a rejected alternative |
| `RejectedAlternative` | alternativa B ("Por qué no otra opción") | The next-best grouping the solver turned down, with its `reasons`: each rule it breaks that the proposal keeps |
| `Season` | temporada | The run of weeks a ronda commits to after ¿seguimos? |
| `Seguimos` | ¿seguimos? | The private vote after the first meeting; the season starts when the yeses reach the pretext's floor (4; fútbol 8) |
| `Rsvp` | voy / esta no | The weekly answer. Default is in; "esta no" never asks why |
| `Anfitrion` | abre ("llega primero") | The host who opens the meeting this month; set by the admin with the place and the hour (`RondaSetup`), then by the monthly turns |
| `Cola` | cierra ("se queda al final") | The co-host who closes; asked first when the anfitrión can't, and next month's anfitrión |
| `HostTurn` | "Este mes abre Jorge y cierra Ana" | One month's anfitrión and cola; a ronda carries this month's and the next two (`turns`). The cola opens next month and the next member closes |
| `Handoff` | ¿Abrís vos? | Finding someone to open one meeting when the anfitrión can't: the cola, then the others coming, then the admin. Whoever says yes is that week's `opener` |
| `Attendance` | ¿Quién vino hoy? | Who came to a meeting, by [Vino] / [No vino]: tapped by the anfitrión or the cola on the meeting's roll (`AttendanceRoll`), read by the admin only |
| `Bench` | banco | Ordered neighbours who take a seat freed by an "esta no" that week: seated nowhere, same pretext and slot, within ten blocks, the seat passing their needs filter, longest waiting first |
| `BenchOffer` | "se liberó un lugar" | One freed seat offered to one person on the bench, with a deadline: [Lo tomo] [Esta vez no] |
| `Guest` | (vas esta vez) | Who took a freed seat: goes to that one meeting, listed in "who's coming" and on the roll, never a member |
| `Despues` | después | The optional 20-minute after-spot the host sets each week; may be a member's home (asked first when it isn't the host's), shown only to that ronda; its address is deleted when the day ends |
| `Buddy` | tu persona de confianza | The member someone chose to write to them after one missed week (`users/{uid}.buddyUid`); told on Friday, by first name only, and opens WhatsApp with no number |
| `Acta` | lo que hizo el programa | The members' log of every organiser-agent action, with "Algo estuvo mal" |
| `AgentRun` | (admin only) | One run of the organiser agent; its steps are the trace, each labelled with who decided it (`by`: code, model or person) |
| `Gate` | (none) | A rule in code that every outgoing message passes (quiet hours, no emoji, voseo, no money, bot disclosure, one routine push a week) |
| `Flyer` | volante | Paper growth: the tear-off flyer and "Hay un mate de más" |
| `Cerca` | cerca tuyo | The public no-login page of open seats and waitlists by barrio |
| `ClientError` | (admin only: "Errores de la app") | One scrubbed error report from the app: where (screen, step), what (code, first line, stack) and when, never who beyond a hashed uid. Web reports land in `client_errors`; Android and iOS go to Crashlytics |
