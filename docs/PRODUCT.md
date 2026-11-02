# Product spec (features in the 9-day build)

Visual reference: the screen canvas (link in `notes/HANDOFF.md`, local only).
The older planilla mockups (`notes/planilla/index.html`) show the research, not the current UI.
Copy below is the real UI copy (rioplatense voseo); English UI mirrors it. Names, places and
dates in the examples are demo data. Everything not listed here is out of the build.

## Screens
- **Mi ronda** (tab): this week's card (day and time, place and distance, después), "¿Venís?"
  with [Voy] [Esta no], who's coming, and under it "Algo chico esta semana" (§ Algo chico esta
  semana). Before a group exists: "Todavía no tenés grupo" and what
  happens next, without promising a seat: "Armamos cada grupo con vecinos que viven cerca y buscan
  lo mismo que vos. Puede tardar, según cuántos se anoten. Cuando haya uno para vos, te avisamos y
  lo vas a ver acá."
  Under the card, the cuaderno's way in (§ El cuaderno del barrio): a pull entry headed by the
  day's hook, with one button, [Abrir el cuaderno]. On the member's own card, the line they chose to bring shows as a
  reminder, "Llevás esta línea: «…»".
- **Cerca** (tab): groups with open places, groups about to start, waiting demand. Also a public
  web page with no login. Until the in-app list exists the tab says so: "Pronto vas a ver acá los
  grupos cerca tuyo que tienen lugar. Mientras tanto, si tenés grupo, lo ves en Mi ronda."
- **Mis datos** (Mi ronda's app bar, and the first row of Ajustes): "Lo que cambies acá lo usamos
  para armar los grupos. Los demás ven solo tu nombre, tu edad y lo que traés." Then the first
  name, the age band, "Dónde podés juntarte" (Casa, with [Cambiar] and "También barrios
  vecinos · Hasta unas N cuadras"; Trabajo: "Si trabajás en otro barrio, también podés juntarte
  ahí. Nadie ve cuál es tu trabajo." [Agregar trabajo], then the same row and [Sacar trabajo]),
  the activities, days and times and what they bring, with onboarding's pickers, and [Guardar].
  A member already in a ronda who changes a barrio or the times reads "Ya estás en una ronda y
  seguís en ella. Si cambiás el barrio o los horarios, cuenta desde la próxima vez que armemos
  grupos." Saving sends the new eligible seat ids first, then the profile.
- **Ajustes** (tab). Built (#54), five rows (Mis datos first):
  - **Avisos:** "Los avisos están prendidos." or "Los avisos están apagados." with what Ronda
    sends, and [Prender los avisos], which forgets "Ahora no" and asks the phone again. A phone
    that refused for good gets the push card's line: "Los avisos de Ronda están apagados en este
    teléfono. Si los querés, prendelos en los ajustes del teléfono."
  - **Contar algo que pasó:** "Contá qué pasó. Lo lee una persona, no un programa. La otra persona
    no se entera de que contaste.", "Escribinos a <address>." and [Escribir un mail] (subject
    "Ronda: algo que pasó"), then the helpline (§ Safety), each number a button that dials it.
  - **Tus datos:** "Lo que Ronda guarda de vos" (name, age band and barrio; days, times,
    activities and what you bring; your ronda and your answers; the Google account or the mobile
    number you sign in with, and this phone's push code; when you accepted the terms), "Lo que no guardamos" (the audio; what makes
    it hard to go, on the phone only), where it lives, and "Para cambiar o borrar tus datos,
    escribinos a <address>." with [Escribir un mail] (subject "Ronda: mis datos", the account id
    in the body). Under "Lo que no guardamos", "Tu cuaderno: queda solo en este teléfono.", and
    below the lists "Tu cuaderno" with [Borrar mi cuaderno]: one question ("¿Borrás todo tu
    cuaderno?") and it is gone from the phone.
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
  guardan en Brasil; el audio lo procesa Meta y el inicio de sesión, Google, en EE. UU."
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
  [Seguir con Google]; [Entrar con mi celular] (#63); "¿No tenés cuenta de Google? Te ayudamos a
  crear una en un minuto.", a link that opens Google's create-account page in the browser. After the voice door, which signs in
  before recording because the server reads the audio: "Para escucharte necesitamos que entres
  con tu cuenta", with the same three lines. Backing out of sign-in keeps the answers on the
  phone. (Signing in at the end of the voice path with a temporary account comes later.)
- **Sign-in by phone** (#63), under either sign-in screen: "Entrar con tu celular". First "¿Cuál
  es tu celular?", "Te mandamos un código por SMS para que entres. Tu número lo usamos solo para
  eso: nadie de tu ronda lo ve.", the field "Tu celular" with "+598 " filled in ("Con o sin el 0,
  como 09X XXX XXX"), [Mandame el código]. A landline: "Ese número es de un fijo. Escribí uno de
  celular, que empiece con 09." Then "Escribí el código", "Te lo mandamos por SMS al +598 9X XXX
  XXX.", "Código de 6 números", [Entrar], "Podés pedir otro en 30 s" turning into [Mandame otro
  código] (waits of 30, 60 and 120 s; after the fourth code "Ya te mandamos varios códigos. Si no
  te llega ninguno, volvé y entrá con Google."), and [Cambiar el número]. An Android phone that
  reads the SMS by itself moves on with no tap. Failures: "Ese código no es. Revisá el SMS y
  probá de nuevo.", "El código venció. Pedí otro.", "Pediste muchos códigos. Probá de nuevo en un
  rato, o entrá con Google.", "Ahora no podemos mandar SMS a ese número. Probá entrar con Google."
- **Voice:** "Te escuchamos", [Grabar] (nothing records before the tap), then "Grabando" with
  the timer and a waveform of the voice (2026-10-30; "No te escuchamos. Revisá el micrófono."
  after about 3 s of silence; "Lo que vamos escuchando" under it when live transcription is on),
  ≤ 60 s, "Qué contar": an example to almost read aloud («Soy Ana,
  tengo 34, vivo en Barrio Sur. Me copa el mate en la rambla y la caminata, los sábados de mañana
  o los martes de tarde. Llevo el termo.») and "Que no falte": Tu nombre · Tu edad, más o menos ·
  Tu barrio · Qué te gustaría hacer (the pretexts) · Qué días, y si de mañana, tarde o noche · Qué
  podés llevar o enseñar (2026-11-01). The needs are never asked aloud: they stay on the phone.
  [Terminé], "Borrar y empezar de nuevo", [Cancelar], and "El audio se borra apenas lo leemos."
  Then "Estamos leyendo tu audio" with its real steps (Mandando tu audio · Escuchándolo ·
  Entendiendo lo que contaste; the one under way breathes, still under reduced motion; words
  heard live skip the first two), the words
  as soon as Voice Transcribe hands them back ("Esto escuchamos" «…», "Tu audio ya se borró.")
  while Spark reads them, and a barrio line every 3 s ("Cebando el mate…", "Buscando quién trae
  los bizcochos…", "Contando sillas en la rambla…"…). A note that named everything goes straight
  to "¿Entendimos bien?"; otherwise "Nos falta poco" asks only what it left out, each with its
  own picker, on one screen, [Seguir] [Grabar de nuevo]. Then "¿Entendimos bien?" with every
  field and a "Cambiar" on each; "Todavía no guardamos nada"; "Tu audio ya se borró."; [Está
  bien, guardalo] [Grabar de nuevo].
- **Microphone blocked:** "No podemos usar el micrófono", three steps to allow it (the phone's
  settings, the browser's padlock on web, or on an iPhone's browser Ajustes → Chrome or Safari →
  Micrófono, then reload; 2026-11-01), or [Prefiero tocar botones].
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
  4. "¿En qué barrio estás?" ("Solo el barrio. Nunca te pedimos la dirección."). 71 barrios:
     Ciudad de la Costa's nine, then Montevideo's 62 (the INE's), each under its heading, with
     "Buscá tu barrio" above them (accents and case aside); nothing matching says "No hay un
     barrio con ese nombre. Probá escribirlo de otra forma."
  5. "¿Qué edad tenés, más o menos?" ("Alcanza con la década. Nunca te pedimos la fecha de
     nacimiento."): De 18 a 29, Treinta y pico … Ochenta o más.
  6. Optional: "¿Hay algo que te complique ir?" ("Caminar mucho", "Subir escaleras", "Volver de
     noche", "No tengo auto"), marked "Queda guardado solo en este teléfono". These become
     filters; the server gets seat ids. [Seguir] [Saltear].
  7. "¿Cómo te llamás?" ("Solo el nombre de pila. Así te conocen en la ronda.").
  Back from the first question (the arrow, the phone's back, the browser's back) returns to the
  welcome doors, signed out; a door opens the questions again from the first. Signed in, it
  opens the recorder, so a voice note that failed can be tried again (2026-11-01).
  Then the read-back "¿Está todo bien?" with every answer and a "Cambiar" on each, "Todavía no
  guardamos nada", and [Está bien, guardalo] (signed out, it keeps the answers on the phone and
  opens the payoff).
- **Before the system asks for notifications:** "¿Te avisamos los martes?" — "Uno por semana,
  el martes a las 19", "Algún otro solo si cambia algo", "Nunca de noche: solo entre las 9 y
  las 21." [Sí, avisame] [Ahora no]. In an iPhone's browser tab, which can't get web push, the
  card and Ajustes → Avisos say instead how to get them (Safari → Compartir → «Agregar a
  inicio», iOS 16.4+), with [Entendido], once (2026-11-01).
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
  checks ("Todos viven a menos de 10 cuadras del punto", 15 in Montevideo, one line per age group, always shown:
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
    day and time, within the walk (10 blocks, 15 in Montevideo), for whom the seat passes what makes it hard to go (on the
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
- **¿Dónde queda?** (#58, built): a weekly barrio photo game on Mi ronda, between meetings. People
  open it themselves: it sends no notification, ends each week and keeps no points.
  - **The turn:** each week one member is asked on the card, in a rotation that is code (by when
    they joined, one on from last week's first; someone paused over the meeting is skipped):
    "Esta semana te toca a vos." "Sacale una foto a algo del barrio: una puerta, un mural, un
    árbol." "Los demás adivinan dónde queda en un mapa. La respuesta sale en la tarjeta de la
    semana que viene." [Sacar la foto] [Esta semana no]. "Esta semana no", or two days without a
    photo, passes the turn to the next member and says why to nobody; once everyone passed there
    is no game that week. A ronda of fewer than three active members has none.
  - **The photo** (phone app only; the web says "Hacelo desde la app del teléfono"): "Mejor sin
    gente: si sale alguien, lo borroneamos antes de subir. Que no se vea el número de ninguna
    casa." Faces are pixelated on the phone with the flyer's preview and "Tocá una cara para
    borronearla". Then "¿Qué es y dónde queda?" (one line, shown only at the reveal: "la puerta
    verde de Gestido y Rivera") and "Una pista, si querés" (one line, shown to everyone now), then
    "Marcá dónde queda": the photographer's pin on the map is the answer. [Mandar la foto] →
    "Revisando la foto. Tarda como medio minuto." → "Listo, tu foto ya está."
  - **Refused, in plain words:** "Se ve el número de una casa. Sacala desde otro lado, sin el
    número.", "La foto es de una persona. Buscá algo del barrio: una puerta, un mural, un árbol.",
    "La foto salió vacía o muy oscura. Probá de nuevo." (each back to the camera) and "Lo que
    escribiste no puede ir: sin direcciones con número ni nombres de personas." (back to the
    words). People passing by and number plates are blurred, not refused.
  - **Guessing:** "Hay una foto del barrio. ¿Sabés dónde queda?" [Poner mi pin] opens the photo,
    "Pista: …", and a small OpenStreetMap map of the barrio ("© colaboradores de OpenStreetMap")
    with "Tocá el mapa donde creés que queda. Tenés un solo pin." [Es acá]. One pin each, during
    the week, until the meeting's day ends; the photographer doesn't guess. Works on web too.
    After: "Ya pusiste tu pin. La respuesta sale en la tarjeta de la semana que viene."
  - **The reveal,** on the next week's card: "La de la semana pasada", "Era la puerta verde de
    Gestido y Rivera." and "Cerca: 3 de 5" (within two and a half blocks of the photographer's
    pin, of those who guessed; "Nadie puso su pin." with none). No names, no points, no ranking,
    no history: the week after, it is gone.
- **Pause:** "Tomarte unas semanas" — 2 semanas / Un mes / Hasta que yo vuelva, each with its
  return date. "Nadie pregunta por qué." Longer than two weeks, the seat is held two weeks and
  then offered to the bench.

## Algo chico esta semana
One small plan a week for a member, with a day, a time and a place, between meetings. Choosing
an activity and fixing when and where is what makes people do it, and the suggestions lean
outward, toward places with people in them. Built in #56.
- **Where:** Mi ronda, under the week's card (only for a member whose ronda has a card), once
  per ISO week: "¿Querés proponerte algo chico para esta semana?" — "Una cosa chica, con día,
  hora y lugar. Se queda solo en este teléfono." [Elegir algo] [Esta semana no]. "Esta semana
  no" keeps the offer away until Monday. A member with no group sees nothing of it.
- **Choosing ("Elegí algo chico"):** a sheet with three ideas and "Decilo vos". Each idea has
  its sentence, its day and time and, outdoors, the forecast: "No se espera lluvia ese día."
  The five kinds are a walk on a route nearby ("Caminar 30 minutos por la Rambla de Solymar"),
  the feria ("Ir a la Feria de Solymar"), the branch library ("Pasar por la Biblioteca Barrial
  de Solymar"), "Llamar a alguien con quien hace tiempo no hablás" and "Una tarde sin el
  celular".
  - The places come from the OSM cache (`osm_places`): plazas, parks, ramblas, libraries and
    `amenity=marketplace` within ten blocks of the member's barrio, checked against
    `opening_hours` where present. A place whose hours the server can't read is not offered, and
    a marketplace with no hours isn't either (nothing says which day the feria is). The distance
    is the same for everyone: sending a shorter one would tell the server about "caminar mucho".
  - Muse Spark Open (Baseten, Spark 1.3 behind it) picks three that fit what the member does in
    their ronda and the week's weather; code builds the candidates and validates the ids, and
    when the model fails the rules pick one of each kind (walk, feria, library, call, no phone).
    The day is Open-Meteo's: a dry day for anything outdoors, within the next seven days.
- **Decilo vos:** by voice or typed. "Contanos qué te gustaría hacer — Hablá o escribí: qué, qué
  día, a qué hora y dónde. Si hablás, el audio se borra apenas lo leemos." [Grabar] (the waveform
  and "Terminé" as in onboarding), a text field ("O escribilo") and [Listo]. Voice Transcribe,
  then Muse Spark 1.3 into a strict `{activity, day, time, place}` (plus its kind), then the
  filter in code, then the day from the forecast: the day the member named if it is dry, else
  the nearest dry day ("El día que dijiste se espera lluvia, así que lo pasamos."), and with
  none the least wet, "Se espera lluvia ese día. Si querés, cambialo." The sheet reads the plan
  back, "¿Es esto?" [Sí, es esto] [Probar de nuevo].
- **The filter** drops the whole plan when it is about a health or medical goal, a diet or
  weight, money, or another person (by name or relationship), or has an emoji, a tú form or a
  home or address in it: "No pudimos armar un plan con eso. Ronda arma planes chicos: salir,
  caminar, ir a algún lugar. Probá con otra cosa." One message whatever the reason, so it never
  names a topic.
- **The plan:** "Caminar 30 minutos por la rambla, el martes a las 19:00, desde la parada
  23." [Agregar al calendario] [Cambiar]. The calendar is the phone's own: on Android and iOS
  the calendar app opens with the event filled in (no calendar permission on Android); on web an
  `.ics` file downloads. Ronda sends no extra push, so the one-routine-push rule holds.
- **Follow-up:** the next week's card asks once, by kind: "¿Saliste a caminar el martes?",
  "¿Fuiste a la feria el martes?", "¿Pasaste por la biblioteca el martes?", "¿Pudiste hacer esa
  llamada el martes?", "¿Pudiste tener tu tarde sin el celular el martes?", or "¿Pudiste hacer lo
  que te propusiste el martes?" [Sí] [Esta vez no]. Both answers get the same reply: "Anotado.
  Gracias por contarnos." No streak, no tally; the plan is deleted when answered.
- **Privacy:** the plan lives in the phone's secure storage under the member's uid, like needs,
  and nothing older than last week is kept. The server never stores who set a plan or who did
  it: the two callables (`suggest_small_plans`, `shape_small_plan`) write no document and log
  only ids, sizes and timings. Voice is sent only after the terms and deleted once read. The
  words go to Meta's models (the same transfer as the voice sign-up).
- **Not built:** a streak or a history. Telling the ronda is ¿Alguien se suma? below.

### ¿Alguien se suma?
The social half of Algo chico (#57): a member opens their plan to their ronda, so it becomes extra
time with the same neighbours in a second place, started by a member rather than organised by
Ronda.
- **The switch:** on the plan's card, "Avisarle a la ronda" — "Tu ronda lo ve la próxima vez que
  abra Mi ronda. Se suma quien quiere." Only when it is turned on does the plan's text leave the
  phone. It isn't offered for a call or an afternoon without the phone (nowhere to join), or once
  the plan's time has passed. Turning it off takes the plan back, with every "Me sumo", and nobody
  hears about it. Choosing another plan ("Cambiar") takes the old one back too, so sharing is
  chosen again for each plan.
- **What the others see:** on Mi ronda, under the week's card, one card per plan still ahead:
  "Ana propone: Caminar 30 minutos por la rambla, el martes a las 19:00, desde la parada 23."
  [Me sumo]. Joined, it says "Te sumaste." with [Ya no voy]. Nothing is pushed: they see it when
  they open Mi ronda, until the plan's time passes. With no plans, nothing shows.
- **What Ana sees:** under her plan, "Se suman: Bruno, Carla." by first name, only once someone
  joined. When nobody does she sees nothing about it and her plan stands as it was. Nothing is
  ever shown as failed, counted or ranked, and a member who takes back "Me sumo" just
  disappears from her line.
- **Checks before sharing** (`functions/shared_plans.py`): in code, the plan is ahead and within
  nine days, at 09:00–21:00, with the organiser's word gates (no emoji, voseo, no money, no home
  or address), the small-plan filter's topics (health, diet, another person) and no phone number;
  then Muse Spark 1.3 confirms the place is public and there is no address, phone number or
  money. A plan that fails any check is held and the plan stays private, with the reason in plain
  words and "Tu plan sigue siendo solo tuyo.": "Solo se comparten planes entre las 9:00 y las
  21:00. Si cambiás la hora, probá de nuevo." (hour), "Para sumar a la ronda hace falta un lugar
  público, como una plaza, la feria o la biblioteca." (no public place), and one line each for
  money, an address or a home, a phone number, words that don't fit, a plan that already passed
  and anything else.
- **Rules:** only members of that ronda (not one who left) read a plan or join it; the plan is
  deleted after its time passes (hourly job) and when its author leaves; the author can
  withdraw it and a member can withdraw "Me sumo". Each member reads only their own card, so
  nobody learns who joined but the author.

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

## El cuaderno del barrio
A private noticing log about the barrio, not a mood log (#59). It never asks "¿cómo te sentís?",
rates anything, keeps a streak or counts days, and never says "ánimo", "bienestar", "mindfulness",
"gratitud" or "salud". Nothing about it is pushed: it is a pull entry on Mi ronda.
- **The hooks:** each place asks something specific, saying what to write and what for. They
  turn with the day of the week, so a weekday always asks the same thing.
  - On Mi ronda the card sells the cuaderno to someone who hasn't opened it, Monday to Sunday:
    "¿Viste un atardecer lindo en la rambla? Anotalo en el cuaderno." / "¿Querés acordarte de
    quién trajo los bizcochos? Para eso está el cuaderno." / "¿Querés una postal de tu semana?
    Escribí unas líneas y te la dibujamos." / "¿Encontraste un rincón nuevo del barrio? Dejalo
    anotado en el cuaderno." / "¿Alguien te enseñó algo? Anotalo en el cuaderno para la
    próxima." / "¿Te acordás de lo que charlaron en la ronda? Guardalo en el cuaderno antes de que
    se te olvide." / "¿Tenés algo para contarle a la ronda? Anotalo y te lo recordamos en tu
    tarjeta." Under it, always: "Una línea sobre tu barrio. La ves solo vos y queda en este
    teléfono."
  - Inside the cuaderno the hook is the prompt for the next line. The day after the ronda's
    meeting and the one after that: "¿De qué charlaron en la ronda? Guardalo antes de que se te
    olvide." With a ronda and three lines or more in the last seven days: "¿Querés que tu postal
    salga más completa? Cada línea de la semana le suma algo." Any other day, Monday first and
    round again: "¿Viste algo lindo en la rambla o en la plaza? Contalo en una línea." /
    "¿Encontraste un rincón nuevo del barrio? Dejalo anotado." / "¿Alguien te enseñó algo?
    Anotalo para la próxima." / "¿Quién trajo qué la última vez? Anotalo y no te lo olvidás." /
    "¿Tenés algo para contarle a la ronda? Anotalo y llevalo."
- **Today's line:** optional, any day, at most one line a day (writing again
  changes that day's line: [Cambiar lo de hoy]). One line typed ("El jacarandá de la esquina
  floreció."), or said: [Decilo con la voz] records up to 30 seconds, Voice Transcribe turns it
  into words (the audio is deleted once read, "El audio se borra apenas lo leemos."), and the
  words land in the field to read and change before [Anotar]. Nothing is written without that tap.
- **Tus líneas:** newest first, each with a menu: [Llevar esta línea] / [Ya no la llevo] and
  [Borrar esta línea] (with [Deshacer]). No counts, no "días seguidos"; an empty cuaderno says
  "Todavía no anotaste nada. Alcanza con lo que veas hoy."
- **Weekly postcard:** on the day before the ronda's meeting, and on the day itself, when the
  last seven days hold at least one line, the cuaderno offers [Dibujar la postal]. Spark 1.3 reads
  the lines and keeps only objects, plants, animals, weather and places as short English phrases
  (no people, names, numbers or anything personal, filtered again in code); the Muse Image prompt
  is built in code from those words alone, and the postcard is objects and places, never people.
  It shows in the cuaderno with [Guardar en el teléfono] (the share sheet) and [Dibujar otra].
  It is held in memory only: it goes away when the cuaderno closes, and saving it is how it is
  kept. The offer says what is sent: "Mandamos las líneas, sin nombres, a un programa que dibuja,
  y no guardamos nada."
- **Bring one line:** the member picks one line, which shows on their own card as "Llevás esta
  línea: «…»". It is a reminder for them: it is **not** shared with the ronda, and there is no
  way to share it yet.
- **Privacy:** the lines live only on the phone (`device_store`, `cuaderno.{uid}`), like needs.
  The postcard callable receives the lines and stores nothing; the image is returned and never
  kept by the server. [Borrar mi cuaderno] in Ajustes → Tus datos deletes everything with one
  question.

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
