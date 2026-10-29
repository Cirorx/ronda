# Product spec (features in the 9-day build)

Visual reference: the screen canvas (link in `notes/HANDOFF.md`, local only).
The older planilla mockups (`notes/planilla/index.html`) show the research, not the current UI.
Copy below is the real UI copy (rioplatense voseo); English UI mirrors it. Names, places and
dates in the examples are demo data. Everything not listed here is out of the build.

## Screens
- **Mi ronda** (tab): this week's card (day and time, place and distance, después), "¿Venís?"
  with [Voy] [Esta no], who's coming. Before a group exists: "Estamos armando tu grupo".
- **Cerca** (tab): groups with open places, groups about to start, waiting demand. Also a public
  web page with no login.
- **Ajustes** (tab): "Tomarme unas semanas", "Cambiarme de grupo", "Dejar Ronda", "Lo que te
  complica ir" (on the phone only), "Tu persona de confianza", "Tus datos", "Contar algo que
  pasó", and the helpline.
- **Admin** (Ciro only): this week's numbers, grupos propuestos, reportes, "Lo que mandó el
  programa", flyer scans per spot.
- (The Bitácora tab from the planilla is not in the build.)

## Onboarding
- Welcome: "Cinco vecinos, a pocas cuadras, el mismo día todas las semanas." Two doors: "Con un
  audio" ("Hablás un minuto, como en WhatsApp.") / "Tocando botones" ("Siete preguntas
  cortas."). Never asks address, cédula, birth date, or whether you live alone. Age is a band
  the person picks ("sesenta y pico").
- **Terms by continuing, no consent screen.** Under the doors: "Al seguir, aceptás las
  condiciones de Ronda." Tapping either door is the acceptance; the app records the terms
  version and the time. The link opens "Las condiciones, en corto": six plain points (free,
  public places and adults only, what is kept, audio deleted at once, see or delete your data
  in Ajustes, reports read by a person) and one line on where things happen: "Tus datos se
  guardan en Brasil; el audio lo procesa Meta y el inicio de sesión Google, en EE. UU."
- **Sign-in** comes after the door: "Primero, entrá con tu cuenta", with "No publicamos nada en
  tu cuenta", "No vemos tus contactos, tus fotos ni tus mails" and "En Ronda te conocen solo por
  tu nombre de pila". [Seguir con Google]; "¿No tenés cuenta de Google? Te ayudamos a crear una
  en un minuto."
- **Voice:** "Te escuchamos", ≤ 60 s, "Ideas de qué contar" shown as a plain checklist while
  recording and ticked on the read-back from what the transcript covered (live ticking would
  need live transcription; decided 2026-10-27),
  [Terminé], "Borrar y empezar de nuevo", [Cancelar], and "El audio se borra apenas lo leemos."
  Then "¿Entendimos bien?" with every field and a "Cambiar" on each; "Todavía no guardamos
  nada"; "Tu audio ya se borró."; [Está bien, guardalo] [Grabar de nuevo].
- **Microphone blocked:** "No podemos usar el micrófono", three steps to allow it, or
  [Prefiero tocar botones].
- **Order:** welcome (doors + terms note) → door → sign-in → the steps. The voice door stays
  hidden until voice onboarding is built. Signed-in people without a profile land on the
  steps; with a profile, on the tabs.
- **Buttons, seven questions and a read-back** (one per screen, "1 de 7"):
  1. "¿Qué te gustaría hacer?" (mate en la rambla, truco, fútbol 5, caminata; "no hace falta
     saber").
  2. "¿Qué podés llevar o enseñar?" (pan, yerba, termo, sillas, enseño truco, tengo ganas).
     "Cada uno pone algo chico. Con una cosa alcanza, y no hace falta comprar nada." "¿No tenés
     nada para llevar? Marcá «Tengo ganas»: venís y listo."
  3. "¿Cuándo podés?", a day × time grid. Mañana: de 9 a 12 · Tarde: de 14 a 18 · Noche: de 19
     a 21.
  4. "¿En qué barrio estás?" ("Solo el barrio. Nunca te pedimos la dirección.").
  5. "¿Qué edad tenés, más o menos?" ("Alcanza con la década. Nunca te pedimos la fecha de
     nacimiento."): De 18 a 29, Treinta y pico … Ochenta o más.
  6. Optional: "¿Hay algo que te complique ir?" ("Caminar mucho", "Subir escaleras", "Volver de
     noche", "No tengo auto"), marked "Queda guardado solo en este teléfono". These become
     filters; the server gets seat ids. [Seguir] [Saltear].
  7. "¿Cómo te llamás?" ("Solo el nombre de pila. Así te conocen en la ronda.").
  Then the read-back "¿Está todo bien?" with every answer and a "Cambiar" on each, "Todavía no
  guardamos nada", and [Está bien, guardalo].
- **Before the system asks for notifications:** "¿Te avisamos los martes?" — "Uno por semana,
  el martes a las 19", "Algún otro solo si cambia algo", "Nunca de noche: solo entre las 9 y
  las 21." [Sí, avisame] [Ahora no].
- The buddy is chosen after the first ronda, not at sign-up.

## Lo que traés (profile)
- First name, age band, what you bring or teach. Initials instead of photos. Open places read
  "Falta alguien que lleve bizcochos, o que tenga ganas." Money is never a requirement.

## Joining and forming rondas
- **No group yet** (Mi ronda): "Estamos armando tu grupo", what we're looking for, how many
  neighbours already match ("Con uno más, arrancamos"), and a fixed date: "El lunes 2/11 a las
  19 te contamos cómo sigue, haya grupo o no." [Ver lugares libres] and "Cambiar lo que busco".
- **An open place:** places left, who goes by age range and count, "Lo organiza Mirta" (the
  host's first name is the only name), what's missing, and "El lugar exacto te lo mostramos el
  día antes, cuando confirmás." [Quiero ese lugar] → "Estás adentro" with the first date and
  when "Así va a ser" arrives; "Me arrepentí" undoes it.
- **Threshold with deadline:** "Hay 4 anotados y hacen falta 6. Si se suman 2 antes del domingo
  1/11, empieza el sábado 7/11." After joining: "Con vos son 5 de 6. Falta uno.", what happens
  if it doesn't fill, [Invitar por WhatsApp], "Salir de la lista".
- **Didn't fill:** "Esta vez no llegamos a 6" with two choices: "Sumarte a otro ya" (a named
  nearby group with places) or "Esperar dos semanas más" (fixed end date and start date). Each
  answer ends with the next date. Never limbo.
- **Changing group:** "¿A qué grupo te querés pasar?" — nearby groups with places, "No hace
  falta explicar por qué." The old seat opens; the old group is told nothing else.
- **Solver + approval:** Ciro sees each proposal, the members (first name, age band, distance),
  checks ("Todos viven a menos de 10 cuadras del punto", "Hay al menos dos de 60 o más", "Ana y
  su invitado van juntos") and "Por qué no otra opción" with its reason. "Nadie recibe nada
  hasta que lo aprobás." [Aprobar y avisarles] → "Aprobado. Les llega el martes a las 19."
  with [Deshacer].
- Rules: +1 pair together, at most one pair per ronda, report-apart pairs never together, open
  a nearby ronda before seating far, cross-age truco partners when both exist.

## The weekly loop
- **Tuesday 19:00 RSVP push:** "Jueves 16:00 · mate frente al quiosco" / "Ya van Mirta, Jorge,
  Ana y Facu. Te toca llevar el pan. Después, si querés, bizcochos en lo de Mirta. ¿Venís?"
  [Voy] [Esta no]. One push a week. Members stay in by default.
- **The card after "Voy":** "Vas. Llevá el pan." "Te esperan el jueves a las 16." with
  "Cambiar mi respuesta". Counts: "Van 4 · 1 no puede · falta tu respuesta".
- **By voice:** "¿Venís? Decilo nomás" — tap the mic, say "voy" or "esta no"; "Escuchamos «Sí,
  voy»" and the result, with "No dije eso". "Solo buscamos «voy» o «esta no». El audio no se
  guarda."
- **Esta no:** never asks why. Sheet: "Listo, esta no. Nadie pregunta por qué." "Tu lugar de
  este jueves se lo ofrecemos a alguien que está esperando." "¿Y las próximas semanas?" [Sigo
  en la ronda] [Pausar 2 semanas], and "Me equivoqué, voy".
- **Who's coming:** first names + what they bring; roles read "Llega primero" (anfitrión) and
  "Se queda al final" (cola); counts (never names) for "no puede" and "sin contestar".
- **Hosts:** rotate monthly: "Este mes abre Jorge y cierra Ana", with the month-by-month turns.
  If the host can't, the cola is asked: "Mirta no puede hoy. ¿Abrís vos?" — "Abrir es llegar
  diez minutos antes, a las 15:50, y saludar a los que van llegando. Nada más." [Sí, abro yo]
  [Hoy no puedo]; a no passes the question on.
- **Bench:** every "esta no" pings the next person on the bench with a deadline: "Se liberó un
  lugar para hoy. Truco en el Club Lagomar, martes 19:30. Estabas en la lista de espera. ¿Lo
  tomás? Tenés hasta las 17:00." [Lo tomo] [Esta vez no]. No fines, ever.
- **Después:** an optional 20-minute after-spot, set each week by the host: "¿Hay después esta
  semana?" [Esta semana no] [a public place nearby] [En lo de alguien del grupo] ("si esa
  persona quiere"). A home is allowed only for the después, never for the ronda itself. It
  shows only to that ronda's members (card and push; never Cerca, the seat page or public
  pages). The host types who, what and the address; if it isn't the host's own home, that
  person is asked first. "La ven solo los de este grupo, y la borramos cuando termina el día."
  Members read on the card "Después, si querés: bizcochos en lo de Mirta, Av. Central 1234 (20
  min)"; the push names the home but never carries the address, since it shows on lock screens.
- **Attendance:** "¿Quién vino hoy?" — the host taps [Vino] / [No vino] per person; "Nadie más
  ve esta lista." No check-in codes.
- **Buddy:** chosen after the first ronda: "Si un día faltás sin avisar, ¿a quién le avisamos?
  Elegí a alguien que ya tenga tu WhatsApp." (a +1 is the natural pick) — "Nadie más se entera,
  y no avisamos a tu familia." After one miss without "esta no", only that person gets "Graciela
  no vino el jueves. Te eligió a vos para estas cosas. ¿Le escribís? Ella no sabe que te
  avisamos." [Le escribo] opens WhatsApp with no number and no text: the buddy opens the chat
  they already have. Ronda never asks for, stores or sends the number (#9). Hidden where WhatsApp
  can't be opened. [Ahora no]. No escalation, no family.
- **Pause:** "Tomarte unas semanas" — 2 semanas / Un mes / Hasta que yo vuelva, each with its
  return date. "Nadie pregunta por qué." Longer than two weeks, the seat is held two weeks and
  then offered to the bench.

## First visit
- **Así va a ser** (two days before): "Te espera Jorge — tiene el termo verde", how to get there
  by landmarks, "Los primeros cinco minutos", and "¿Te querés ir antes? Decí «me tengo que ir»
  y listo. Nadie se ofende."
- **A named member waits:** the host is asked "Nico viene por primera vez el jueves. ¿Quién lo
  espera en el quiosco a las 15:50?" and picks "Lo espero yo" or another member, with how to be
  recognised ("Tengo el termo verde"); the screen previews what Nico will see.
- **Spot photo** the day before, 18:00, confirmed members only: "Es en este banco"; SAM 3.1
  outlines the bench; "La gente que pasaba sale borrosa. Esta foto la ven solo los que van."
- **"No los encuentro"** → the host gets "Nico llegó y no los encuentra" [Voy a buscarlo] [Ya
  lo veo]; the newcomer sees "Le avisamos a Jorge que estás cerca. Tu número no se comparte."
- **Weeks 2–3:** before RSVP closes, the host (not the newcomer) gets "¿Viene Nico el jueves?"
  [Sí, viene] [Esta semana no] [No sé]; "No sé" holds the seat until Wednesday 19:00. "Nico no
  se entera de que te preguntamos."
- **¿Seguimos?** after meeting 1, private: "¿Seguimos los jueves? Solo Ronda ve tu respuesta.
  Nadie del grupo se entera de lo que digas." Every active member is asked; the answer can change
  until the question closes with the next RSVP push. The season starts when the yeses alone
  could be a ronda: the pretext's floor (4; fútbol 8), whatever the group's size (#9). "Si no
  contestás, seguís en la ronda, pero no cuenta como un sí." A "no" gets "Gracias por venir."
  and two nearby alternatives; their seat reopens at the close, not on answering, so the timing
  gives nobody away. Result, with that push: "Seguimos los jueves", the season's end date,
  "Nadie sabe qué contestó cada uno." No count, no names; the admin sees counts only. Below the
  floor there is no season, and everyone still in gets the **Didn't fill** choices.

## Organiser agent (what members see)
- **First message:** "Hola, Graciela. Soy un programa. Ronda me usa para avisar horarios,
  lugares y lluvia. Las decisiones las toman ustedes. Nunca escribo de noche."
- **Rain**, Wednesday 18:00, to the host only: "El jueves puede llover" — "Jueves 16:00 · lluvia
  80%. Ráfagas de 50 km/h en la rambla. Pronóstico de Open-Meteo." [Al Club Solymar] [Pasarla
  al viernes] [Vamos igual]. "Lo que elijas les llega a los 6 en un solo mensaje. Si no
  contestás antes de las 21, queda como está." The host sees the exact message before it goes,
  e.g. "Por la lluvia, el jueves nos vemos en el Club Solymar a las 16:00. Lo decidió Mirta."
- **Winter:** sunset and last bus on every card ("Atardece 17:44", "Último ómnibus de la rambla
  21:10"); the agent suggests starting before 17:00 June–August, and the card says "En invierno
  empezamos una hora antes, para volver con luz. Lo decidió Mirta."
- **Ronda se calla:** from week 2, jobs move to members: "Jorge, ¿avisás vos cuando llueve?" The
  agent drafts, the member sends from their own WhatsApp: [Mandarlo por WhatsApp] [Cambiar el
  texto], or "Prefiero que lo siga mandando Ronda".
- **El acta:** "Lo que hizo el programa" — a short, factual weekly log ending "No leyó mensajes
  de nadie ni mandó nada fuera de horario."; [Algo estuvo mal].
- Logistics only. Never 21:00–09:00. Admin sees every message as "Salió" or "Frenado" with the
  reason (e.g. "Frenado: fuera de horario. Salió el jueves a las 9:00.").

## Cerca tuyo (public, no login)
- "Cerca tuyo" — "Grupos de 5 o 6 vecinos que se juntan una vez por semana, siempre en lugares
  públicos." A barrio picker; rows: activity · time band · age range · places left ("Quedan 2",
  "4 de 6", "Lleno" with its waiting list); waiting demand ("9 vecinos esperan que arranque una
  caminata en El Pinar"). "No mostramos nombres ni lugares exactos." No pins, no exact spots.
  Exact spot only to confirmed members, the day before.

## Flyers
- **Tear-off:** lost-pet format: "¿Te sumás a un mate?", one line on what it is, three facts
  (day and place, 5 or 6 neighbours of all ages, "No hace falta traer nada"), "Arrancá una tira
  y escaneala.", seven strips each with a QR tied to where the flyer hangs. "Ronda nunca pide
  plata" printed. The QR landing, "Cerca de este volante", shows only rondas within walking
  distance of that spot and that stop's last bus; [Quiero sumarme], "Funciona en el navegador;
  no hace falta bajar nada." Phone number answered by a person (later).
- **Un mate de más:** from week 4 each ronda keeps one newcomer seat. The host photographs the
  group's things: "Sacale una foto a las cosas del grupo. Mejor sin gente: si sale alguien, lo
  borroneamos antes de subir." Faces blurred on the phone; on the preview the host can tap any
  face the detector missed to blur it too ("Tocá una cara para borronearla") → SAM 3.1 cuts out
  termo, mazo, mates
  → Muse Image makes the background; "Hay un mate de más. Es tuyo." and the QR are drawn in
  code. Preview: "Así queda tu volante" [Imprimir o compartir]. Phone app only (no face
  detection on web): the web app says "Hacelo desde la app del teléfono".

## Truco
- "Campeonato de los martes", 3 v 3, "Los equipos cambian cada semana. Así todos juegan con
  todos." Under-30 paired with over-60 where both exist; the +1 stays on the friend's team. A
  table where each win gives 2 points to the three on the team. Sold as a campeonato, never
  "intergenerational".
- Kept (#9): the solver's cross-age rule ships. The in-app team draw and the points table come
  after 11-04; until then the card states the house rule and teams are drawn at the table.

## Safety
- **Contar algo que pasó** (voice or text): "Contá qué pasó. Lo lee una persona, no un
  programa. La otra persona no se entera de que contaste." Tags: "Me pidió plata", "Me
  molestó", "Insistió con algo romántico", "Había un menor", "Quiso ir a un lugar privado",
  "Otra cosa"; "¿Con quién?"; "Si estás en peligro ahora, llamá al 911."
- Ciro's queue puts anyone reported in two rondas on top; actions [Sacar de Ronda]
  [Separarlos], or for small things [Pasarle a Mirta] [Archivar]. Report-apart pairs never
  seated together. The agent may only move a ronda to a public place in OSM, host confirms.
- The ronda always meets in a public place, adults only; only the después may be at a home,
  when the host sets it. Helpline in Ajustes: "¿Necesitás hablar con alguien ahora?"
  Línea de Prevención del Suicidio 0800 0767 / *0767, Emergencias 911.

## Your data and leaving
- **Tus datos:** "Lo que Ronda guarda de vos" — every stored field in plain words, "Lo guardamos
  en Brasil", and "Lo que no tenemos" (audio deleted; what makes it hard to go stays on the
  phone). [Bajar una copia] and "Borrar todo y dejar Ronda".
- **Dejar Ronda:** "¿Dejás Ronda?" — everything is deleted, the seat opens with no message to the
  group, coming back starts from zero. Offers [Mejor pauso] first, then [Dejar Ronda y borrar
  todo] → "Listo. Gracias por estos jueves."

## Text size and dark mode
- At 200% text everything stacks: full-width buttons, names and roles on separate lines, the
  screen scrolls. Tab labels grow only to about 1.3×. The day × time grid becomes, per day, three
  chips (Mañana, Tarde, Noche) that wrap.
- Dark mode follows the system and uses the night tokens in `docs/DESIGN.md`.

## Demo video
The script, shot list and the 45-second X cut are in `notes/DEMO.md` (local only).
