# Product spec (features in the 9-day build)

Visual reference: the screen canvas (link in `notes/HANDOFF.md`, local only).
The older planilla mockups (`notes/planilla/index.html`) show the research, not the current UI.
Copy below is the real UI copy (rioplatense voseo); English UI mirrors it. Names, places and
dates in the examples are demo data. Everything not listed here is out of the build.

## Screens
- **Mi ronda** (tab): this week's card (day and time, place and distance, después), "¿Venís?"
  with [Voy] [Esta no], who's coming. Before a group exists: "Todavía no tenés grupo" and what
  happens next, without promising a seat: "Armamos cada grupo con vecinos que viven cerca y buscan
  lo mismo que vos. Puede tardar, según cuántos se anoten. Cuando haya uno para vos, te avisamos y
  lo vas a ver acá."
- **Cerca** (tab): groups with open places, groups about to start, waiting demand. Also a public
  web page with no login. Until the in-app list exists the tab says so: "Pronto vas a ver acá los
  grupos cerca tuyo que tienen lugar. Mientras tanto, si tenés grupo, lo ves en Mi ronda."
- **Ajustes** (tab). Built (#54), four rows:
  - **Avisos:** "Los avisos están prendidos." or "Los avisos están apagados." with what Ronda
    sends, and [Prender los avisos], which forgets "Ahora no" and asks the phone again. A phone
    that refused for good gets the push card's line: "Los avisos de Ronda están apagados en este
    teléfono. Si los querés, prendelos en los ajustes del teléfono."
  - **Contar algo que pasó:** "Contá qué pasó. Lo lee una persona, no un programa. La otra persona
    no se entera de que contaste.", "Escribinos a <address>." and [Escribir un mail] (subject
    "Ronda: algo que pasó"), then the helpline (§ Safety), each number a button that dials it.
  - **Tus datos:** "Lo que Ronda guarda de vos" (name, age band and barrio; days, times,
    activities and what you bring; your ronda and your answers; the Google account and this
    phone's push code; when you accepted the terms), "Lo que no guardamos" (the audio; what makes
    it hard to go, on the phone only), where it lives, and "Para cambiar o borrar tus datos,
    escribinos a <address>." with [Escribir un mail] (subject "Ronda: mis datos", the account id
    in the body).
  - **Salir de esta cuenta:** "¿Salís de esta cuenta?" — your group and answers stay; this phone
    stops getting notifications. [Salir] forgets this phone's push token, then signs out.
  - The address is one build value, `RONDA_CONTACT_EMAIL` (`docs/STACK.md` § Pilot builds); a
    person reads it. There is no in-app report form, no "Bajar una copia" and no "Borrar todo"
    yet: changes and deletions are done by hand on request.
  - Still to come: "Tomarme unas semanas", "Cambiarme de grupo", "Dejar Ronda", "Lo que te
    complica ir" (on the phone only). "Tu persona de confianza" is chosen and changed on Mi
    ronda for now (§ The weekly loop, Buddy).
- **Admin** (Ciro only): this week's numbers, grupos propuestos, reportes, "Lo que mandó el
  programa", flyer scans per spot, and "Lugar, hora y anfitriones" (each ronda's public place,
  hour and hosts, its latest "¿Quién vino?", and how the coming meeting's "¿Abrís vos?" is going:
  "Buscando quién abre el 5/11: Mirta no puede.", "El 5/11 abre Facu en lugar de Mirta." or
  "Nadie confirmó que abre el 5/11: Mirta no puede."), and "Errores de la app" (`/admin/errores`:
  what the web app reported in the last 30 days, grouped by what failed and where, with how many
  times, the last time and the platforms; a group opens its newest reports. Android and iPhone
  errors are in the Crashlytics console).
- (The Bitácora tab from the planilla is not in the build.)

## Onboarding
- **¿Cómo funciona?** (`/como-funciona`, 2026-10-31): three cards before the welcome doors, the
  first time a signed-out person opens the app on a phone; once they leave it for the doors the
  phone remembers, and the welcome screen's "¿Cómo funciona?" link opens it again. A link to a screen, the welcome
  screen itself (the flyers' and Cerca tuyo's [Quiero sumarme] open it) and `?from=/admin` go
  straight on.
  1. "Los mismos 5 o 6, cada semana" — "A pocas cuadras, con una excusa: mate en la rambla,
     truco, fútbol 5." Drawn as the mate, the mazo and the pelota.
  2. "Un aviso por semana, nada más" — a sample of the weekly card, "Jueves 16:00 · Rambla y
     Gestido" with "¿Venís?" [Voy] [Esta no] as a picture (nothing to tap), then "No hay nada
     que revisar todos los días. Si no podés, tocás «Esta no» y nadie pregunta por qué."
  3. "Un programa se encarga del resto" — "Avisa si llueve, busca quién abre y quién toma tu
     lugar si no vas. Las decisiones las toman ustedes." Drawn as objects (umbrella, key,
     chair), never people.
  Page dots, "Saltear" on every card, [Seguir] and on the last card [Empezar], both to the
  doors. The cards swipe on the app's spring and follow the arrow keys; wide windows keep them to
  the readable column.
- Welcome: "Cinco vecinos, a pocas cuadras, el mismo día todas las semanas." Two doors: "Con un
  audio" ("Hablás un minuto, como en WhatsApp.") / "Tocando botones" ("Siete preguntas
  cortas."). Never asks address, cédula, birth date, or whether you live alone. Age is a band
  the person picks ("sesenta y pico").
- **Terms by continuing, no consent screen.** Under the doors: "Al seguir, aceptás las
  condiciones de Ronda." Tapping either door is the acceptance; the app records the terms
  version and the time, held on the phone until sign-in and written right after it. The link opens "Las condiciones, en corto": seven plain points (free,
  public places and adults only, what is kept, audio deleted at once, see or delete your data
  in Ajustes, reports read by a person, and "Si algo falla, la app manda un aviso anónimo, sin
  tus datos, para que lo arreglemos.") and one line on where things happen: "Tus datos se
  guardan en Brasil; el audio lo procesa Meta y el inicio de sesión Google, en EE. UU."
- **Payoff** after the read-back, signed out: "Esto es lo que hay para vos", from the answers and
  Cerca tuyo's public `cerca/{barrio}` counts. It shows demand, never seats: "Hay 4 anotados para
  mate los sábados de tarde cerca tuyo." (the slot only where the counts have one; otherwise "Hay
  4 anotados para mate cerca tuyo."), then "Te avisamos cuando se arme tu ronda." With nobody
  else: "Sos de los primeros en tu zona: te avisamos cuando seamos cinco." Offline or unreadable:
  "Ahora no pudimos ver quién más se anotó cerca tuyo." No names, places or "4 de 6": nothing yet
  lets a new sign-up take a seat in an existing ronda, and the solver can still split or trim a
  group. [Guardame el lugar] leads to sign-in.
- **Sign-in** after the payoff: "Guardá tu lugar", "Para guardarte el lugar y avisarte el día de
  la ronda, entrá con tu cuenta.", with "No publicamos nada en tu cuenta", "No vemos tus
  contactos, tus fotos ni tus mails" and "En Ronda te conocen solo por tu nombre de pila".
  [Seguir con Google]; "¿No tenés cuenta de Google? Te ayudamos a crear una en un minuto.", a link
  that opens Google's create-account page in the browser. After the voice door, which signs in
  before recording because the server reads the audio: "Para escucharte necesitamos que entres
  con tu cuenta", with the same three lines. Backing out of sign-in keeps the answers on the
  phone. (Signing in at the end of the voice path with a temporary account comes later.)
- **Voice:** "Te escuchamos", [Grabar] (nothing records before the tap), then "Grabando" with
  the timer and a waveform of the voice (2026-10-30; "No te escuchamos. Revisá el micrófono."
  after about 3 s of silence), ≤ 60 s, "Ideas de qué contar" shown as a plain checklist while
  recording and ticked on the read-back from what the transcript covered (live ticking would
  need live transcription; decided 2026-10-27),
  [Terminé], "Borrar y empezar de nuevo", [Cancelar], and "El audio se borra apenas lo leemos."
  Then "¿Entendimos bien?" with every field and a "Cambiar" on each; "Todavía no guardamos
  nada"; "Tu audio ya se borró."; [Está bien, guardalo] [Grabar de nuevo].
- **Microphone blocked:** "No podemos usar el micrófono", three steps to allow it (the phone's
  settings, or the browser's padlock on web), or [Prefiero tocar botones].
- **Voice failures** say what failed, each with [Prefiero tocar botones]: "No encontramos un
  micrófono", "No pudimos grabar", "No pudimos mandar el audio" (the connection: try again; or
  refused by the server: "Es un problema nuestro, no tuyo", buttons only), "Falta aceptar las
  condiciones" (buttons only), "No pudimos leer el audio".
- **Order (buttons):** (on a first open, "¿Cómo funciona?") → welcome (doors + terms note) →
  the seven questions and the read-back, signed out → the payoff → "Guardá tu lugar" sign-in → the profile and the terms saved → Mi
  ronda. Until sign-in the answers and the terms stay on the phone, so backing out of sign-in
  or closing the app doesn't mean answering again. **Order (voice):** welcome → sign-in → the
  recording → "¿Entendimos bien?" → saved. Signed-in people without a profile land on the steps
  (or straight on the save, when the phone holds answers); with a profile, on the tabs.
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
  Back from the first question (the arrow, the phone's back, the browser's back) returns to the
  welcome doors, signed out; a door opens the questions again from the first.
  Then the read-back "¿Está todo bien?" with every answer and a "Cambiar" on each, "Todavía no
  guardamos nada", and [Está bien, guardalo] (signed out, it keeps the answers on the phone and
  opens the payoff).
- **Before the system asks for notifications:** "¿Te avisamos los martes?" — "Uno por semana,
  el martes a las 19", "Algún otro solo si cambia algo", "Nunca de noche: solo entre las 9 y
  las 21." [Sí, avisame] [Ahora no].
- The buddy is chosen after the first ronda, not at sign-up.

## Lo que traés (profile)
- First name, age band, what you bring or teach. Initials instead of photos. Open places read
  "Falta alguien que lleve bizcochos, o que tenga ganas." Money is never a requirement.

## Joining and forming rondas
- **No group yet** (Mi ronda): built as the two lines in § Screens. Still to come: what we're
  looking for, how many neighbours already match ("Con uno más, arrancamos"), and a fixed date: "El lunes 2/11 a las
  19 te contamos cómo sigue, haya grupo o no." [Ver lugares libres] and "Cambiar lo que busco".
- **An open place:** places left, who goes by age range and count, "Lo organiza Mirta" (the
  host's first name is the only name), what's missing, and "El lugar exacto te lo mostramos el
  día antes, cuando confirmás." [Quiero ese lugar] → "Estás adentro" with the first date and
  when "Así va a ser" arrives; "Me arrepentí" undoes it.
- **Threshold with deadline:** "Hay 4 anotados y hacen falta 6. Si se suman 2 antes del domingo
  1/11, empieza el sábado 7/11." After joining: "Con vos son 5 de 6. Falta uno.", what happens
  if it doesn't fill, [Invitar por WhatsApp], "Salir de la lista".
  - Built (#48) on Mi ronda before a group exists, under "Todavía no tenés grupo": "Tu lista de
    espera", the list's line ("Sábado a la tarde · Mate en la rambla"), "Con vos son 5 de 6.
    Falta uno." ("Por ahora sos la primera persona anotada. Hacen falta 6." alone), "Si se suma
    uno más antes del domingo 1/11, empieza el sábado 7/11." and "Si no llegamos, te damos a
    elegir: sumarte a otro grupo o esperar dos semanas más." A full list reads "Ya son 6:
    alcanza para arrancar. Armamos el grupo y te avisamos antes del sábado 7/11." Counts and
    dates only. Six is the pretext's largest ronda (fútbol 10); a round runs to a Sunday and
    the ronda would start on its day the week after. The payoff, signed out, still shows demand
    only. [Invitar por WhatsApp] and "Salir de la lista" are not built.
- **Didn't fill:** "Esta vez no llegamos a 6" with two choices: "Sumarte a otro ya" (a named
  nearby group with places) or "Esperar dos semanas más" (fixed end date and start date). Each
  answer ends with the next date. Never limbo.
  - Built (#48) for the waiting list on the same card: "Esta vez no llegamos a 6.", "¿Cómo
    seguís?", [Sumarte a otro ya] with "Jueves a la noche · Truco, el jueves 5/11" (shown only
    when a nearby ronda has places) and [Esperar dos semanas más] with "Esperamos hasta el
    domingo 15/11. Si se suman, arranca el sábado 21/11." Joining reads "Listo, lo anotamos. Te
    confirmamos el lugar antes del jueves 5/11." and the admin seats them with "Sumar a esta
    ronda"; waiting shows the next round. A round that ends short again asks again.
- **Changing group:** "¿A qué grupo te querés pasar?" — nearby groups with places, "No hace
  falta explicar por qué." The old seat opens; the old group is told nothing else.
- **Solver + approval:** Ciro sees each proposal, the members (first name, age band, distance),
  checks ("Todos viven a menos de 10 cuadras del punto", one line per age group, always shown:
  "60 o más (2): nadie es el único de su edad" or "Menos de 30 (1): Facu es la única persona de
  su edad", "Ana y su invitado van juntos") and "Por qué no otra opción" with its reason.
  "Nadie recibe nada hasta que lo aprobás." [Aprobar y avisarles] → "Aprobado. Les llega el
  martes a las 19." with [Deshacer]. Under the groups, who is left out: "2 personas quedan sin
  lugar por ahora." and each by first name, barrio and the slots they picked.
- **Sumar a esta ronda** (admin, on an approved ronda): "3 de 6 lugares ocupados", then every
  sign-up not in it, with what doesn't match ("No eligió este día y horario", "Vive a más de 10
  cuadras", "Su teléfono no marcó este lugar como posible") and "Ya está en …" for someone in
  another ronda. [Sumar], or [Pasar a esta ronda] → "¿Pasar a Jorge?" "Deja … No le llega ningún
  aviso a nadie." [Pasar]. "Listo: Eva está en la ronda. Lo ve en Mi ronda; no le mandamos
  ningún aviso." A full ronda: "No queda lugar: es el máximo para esta actividad."
- **Los números del piloto** (admin): "Completaron el perfil: 9 de 10 anotados", "En una ronda:
  6 de 9", "Volvieron a la segunda reunión: 1 de 3", and per ronda "Miembros: 5 de 6", each
  week "31/10: van 3 de 5 · no pueden 1 · sin contestar 1" and "Vinieron: 3 de 4 marcados",
  and "¿Seguimos?: sí 3 de 4 · no 1 · sin contestar 0". Demo sign-ups never count.
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
  - Built so far (#47): the admin chooses the anfitrión and the cola, sets the public place
    ("frente al quiosco", with how to find it: "al lado de la parada") and the hour inside the
    band, on "Lugar, hora y anfitriones". Approval leaves all three empty and nothing invents
    them: until set the card says "Lugar y hora a confirmar" (or "Lugar a confirmar", "Hora a
    confirmar"), the push says the same, and there is no host. The card reads "Abre Mirta.
    Cierra Jorge."; the anfitrión reads "Abrís vos: llegás diez minutos antes y saludás a los que
    van llegando." and the cola "Cerrás vos: te quedás hasta el final." A place that looks like a
    home or an address is refused ("La ronda se junta solo en lugares públicos").
  - The monthly turns (#50's `assign_hosts`, built): the admin's pick is this month's turn and
    stays the override. Each new month the cola opens and the next member, by when they
    joined, closes, skipping anyone paused or gone. Nothing starts the turns but the admin. The
    card adds "Este mes abre Jorge y cierra Ana. Los próximos turnos: diciembre, abre Ana y
    cierra Facu; enero, …", and the acta "Este mes abre Ana y cierra Facu. Así toca por turno."
    marked "Regla fija". No push: the turns show months ahead.
  - "¿Abrís vos?" (built): when the anfitrión said "esta no", is paused or gone, or hasn't
    answered by noon the day before, the cola gets "Mirta no puede el jueves. ¿Abrís vos?" (or
    "Mirta no confirmó que viene el jueves.") with what opening is, on the card and in a push.
    The cola has two hours; then everyone else coming gets "Todavía nadie abre el jueves.
    ¿Abrís vos?", which names nobody. The first [Sí, abro yo] opens it, says "voy" for them, and
    the card reads "Esta semana abre Facu." ("Esta semana abrís vos: …" for them); they get the
    attendance ask. With nobody by the start, the admin sees "Nadie confirmó que abre". The
    anfitrión's "voy" ends it. Nothing is asked from 21:00 to 09:00. Fixed rules in code, not
    the model; the acta says who was asked and who opens, never why the anfitrión can't.
- **Bench:** every "esta no" pings the next person on the bench with a deadline: "Se liberó un
  lugar para hoy. Truco en el Club Lagomar, martes 19:30. Estabas en la lista de espera. ¿Lo
  tomás? Tenés hasta las 17:00." [Lo tomo] [Esta vez no]. No fines, ever.
  - Built (#48, with #50's `offer_bench_seat`). The push: "Se liberó un lugar para hoy" (or
    "para mañana", "para el jueves 5/11") / "Martes 19:30 · truco · Club Lagomar. Estabas en la
    lista de espera. ¿Lo tomás? Tenés hasta las 17:00." with [Lo tomo] [Esta vez no] on
    Android, answered without opening the app ("Listo, el lugar es tuyo." / "Listo, esta vez
    no. Seguís en la lista de espera."). On Mi ronda the same offer shows on top, "Si no podés,
    no pasa nada: seguís en la lista de espera.", and once taken "Vas esta vez" with where,
    "Tomás el lugar que alguien liberó, solo para esta reunión."
  - Who is on the bench, in order, is code's: sign-ups in no ronda who picked that activity,
    day and time, within ten blocks, for whom the seat passes what makes it hard to go (on the
    phone), longest waiting first. One offer per freed seat at a time; "Esta vez no" or a
    passed deadline moves to the next person; a member who says "voy" again takes the free
    seat back from a pending offer. Nothing is held against anyone.
  - The organiser decides whether an offer is worth sending (hours left, rain, the last bus),
    its deadline among the hours code allows (on the hour, 09:00 to 20:00, at least an hour
    away and an hour before the meeting), and when the host hears how the bench went:
    "Lugares libres del jueves" / "Para mañana se liberó un lugar. Eva viene de la lista de
    espera." (never who said no). Without its decision Ronda offers with a deadline about
    three hours away and tells the host once the bench is done.
  - Who takes a seat is a guest of that meeting: they show in "who's coming" and on the
    host's "¿Quién vino hoy?", not as a member, in ¿seguimos? or in the pilot's numbers.
- **Después:** an optional 20-minute after-spot, set each week by the host: "¿Hay después esta
  semana?" [Esta semana no] [a public place nearby] [En lo de alguien del grupo] ("si esa
  persona quiere"). A home is allowed only for the después, never for the ronda itself. It
  shows only to that ronda's members (card and push; never Cerca, the seat page or public
  pages). The host types who, what and the address; if it isn't the host's own home, that
  person is asked first. "La ven solo los de este grupo, y la borramos cuando termina el día."
  Members read on the card "Después, si querés: bizcochos en lo de Mirta, Av. Central 1234 (20
  min)"; the push names the home but never carries the address, since it shows on lock screens.
  - Built (#47): the anfitrión, the cola or whoever opens that week sets it from the card
    (¿Hay después esta semana?): "Esta semana no", a public place ("¿Qué hay?", "¿Dónde?"),
    or "En lo de alguien del grupo" (themselves or anyone coming, and the address: "Nunca va en
    un aviso…"). Someone else's home asks that person first, on their card and in a push that
    names neither the home nor the address ("Mirta pregunta si el después de esta semana puede
    ser donde vivís."); members see nothing until [Sí, puede ser]. [Mejor no] deletes the
    address, and the host reads "Ana prefiere que no sea donde vive." The words pass the word
    gates (no money, no emoji; a public place can't read as an address). Set before the RSVP
    push, it rides in it: "Después, si querés, bizcochos en lo de Mirta."; set after, it shows
    on the card only. The address is deleted once the meeting's day ends.
- **Attendance:** "¿Quién vino hoy?" — the host taps [Vino] / [No vino] per person; "Nadie más
  ve esta lista." No check-in codes. It is asked an hour into the meeting (20:00 at the latest,
  before the quiet hours) of the anfitrión, or the cola when the anfitrión said "esta no" or
  is paused (whoever took over opening comes first); a tap on the push opens the roll, on
  Android too, and the card shows the anfitrión and the cola "¿Quién vino hoy?" with how many
  are marked. Taps can be corrected for six days. The list has everyone in
  the ronda for that meeting in first-name order, "esta no" included, so it gives nobody's
  answer away. With no host the admin records it from "Lugar, hora y anfitriones". Members
  never see who came; the admin sees the record.
- **Buddy:** chosen after the first ronda: "Si un día faltás sin avisar, ¿a quién le avisamos?
  Elegí a alguien que ya tenga tu WhatsApp." (a +1 is the natural pick) — "Nadie más se entera,
  y no avisamos a tu familia." After one miss without "esta no", only that person gets "Graciela
  no vino el jueves. Te eligió a vos para estas cosas. ¿Le escribís? Graciela no sabe que te
  avisamos." (the name again, not "Ella": Ronda keeps no gender). [Le escribo] opens WhatsApp
  with no number and no text: the buddy opens the chat they already have. Ronda never asks for,
  stores or sends the number (#9). Hidden where WhatsApp can't be opened, and on web. [Ahora
  no]. No escalation, no family.
  - Built (#50's `prompt_buddy`): the question shows on Mi ronda once a meeting has passed
    since the member joined, with the other members by first name, [Elegir] and [Ahora no]
    (nobody, which stops the question). Then "Si faltás sin avisar, le avisamos a Ana. Nadie
    más se entera." [Cambiar], or "…no le avisamos a nadie." [Elegir a alguien]. On Fridays
    from 10:00, a member marked [No vino] at a meeting in the past week, who hadn't said "esta
    no" and wasn't paused, is mentioned once to their buddy only: a push, and the card on the
    buddy's Mi ronda. A fixed rule in code; it is in the admin's trace and never in the acta.
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
  detection on web): the web app says "Hacelo desde la app del teléfono". Its QR opens the
  same `/f/{id}` page under its own heading: "Hay un mate de más cerca tuyo", "Una ronda de este
  barrio guarda un lugar para alguien nuevo: 5 o 6 vecinos que se juntan una vez por semana,
  siempre en lugares públicos.", the rondas of that barrio, and no bus.

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
