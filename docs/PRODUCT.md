# Product spec (features in the 9-day build)

Visual reference: the mockup flows in `docs/planilla/index.html` (filter "In the 9-day build").
Copy below is the real UI copy (rioplatense voseo); English UI mirrors it. Everything not listed
here is out of the build (see `docs/PLAN.md`).

## Screens
- **Mi ronda** (tab): this week's card, who's coming, hosts, después, spot, RSVP.
- **Cerca** (tab): open seats and waitlists near you; also a public web page with no login.
- **Ajustes** (tab): pausa, salir, cambiar de ronda, reportar, mis datos, lo que te cuesta
  (needs, on the phone), tu persona (buddy), helpline.
- **Admin** (Ciro only): proposals, reports, flyers.
- (The Bitácora tab from the mockups is not in the build.)

## Onboarding
- Two doors: "Contalo en un audio" / "Prefiero tocar botones". Never asks address, cédula,
  birth date, or whether you live alone. Age is a band the person picks ("sesenta y pico").
- Voice: consent screen first ("Tu audio lo procesa Meta en EE. UU. y se borra apenas lo
  leemos. Tus datos se guardan en Brasil y tu inicio de sesión lo procesa Google en EE. UU."), ≤ 60 s, then
  read-back with every field editable. Nothing is saved until "Está bien".
- Buttons: activities, "¿Qué podés traer o enseñar?" (pan, yerba, termo, sillas, enseño truco,
  tengo ganas), a day × morning/afternoon/night grid, barrio picker.
- Needs ("caminar poco", "sin escaleras", "antes de que oscurezca", "sin auto") are shown under
  "Lo que te cuesta — lo sabe solo este teléfono" and become filters; the server gets seat ids.
- The buddy is chosen after the first ronda, not at sign-up.

## Lo que traés (profile)
- First name, age band, what you bring or teach. Initials instead of photos. Open seats read
  "Falta uno que traiga bizcochos — o que tenga ganas". Money is never a requirement.

## Joining and forming rondas
- Join an open seat, or a waitlist for barrio × pretext × slot.
- **Threshold with deadline:** "Somos 4 de 6. Si llegamos a 6 antes del domingo 26, arrancamos
  el sábado 1/11." If it doesn't fill: offer the nearest open ronda at once, or wait two more
  weeks with a fixed date. Never limbo.
- **Solver + approval:** Ciro sees each proposal, the members (first name, age band, distance),
  checks ("✓ todos a menos de 10 cuadras", "✓ dos o más de 60+", "✓ par +1 junto") and at least
  one rejected alternative with its reason. Nobody is told anything before "Aprobar".
- Rules: +1 pair together, at most one pair per ronda, report-apart pairs never together, open
  a nearby ronda before seating far, cross-age truco partners when both exist.

## The weekly loop
- **Tuesday 19:00 RSVP push:** "Jueves 16:00 · mate frente al quiosco. Ya van Mirta, Jorge, Ana
  y Facu. Te toca: el pan · después, bizcochos en lo de Rosa." [Voy] [Esta no]. One push a week.
  Members stay in by default. A voice "sí"/"voy" counts.
- **Esta no:** never asks why. Sheet: "Listo, esta no. Nadie pregunta por qué." [Guardame el
  lugar] [Pausar 2 semanas].
- **Who's coming:** first names + what they bring; counts (never names) for "no" and "sin
  contestar".
- **Hosts:** anfitrión opens, cola closes; rotate monthly. If the host can't, the cola is asked:
  "Mirta no puede hoy. ¿Abrís vos?".
- **Bench:** every "esta no" pings the next person on the bench with a deadline: "Falta 1 hoy,
  martes 21:30. ¿Lo tomás? Tenés hasta las 19." No fines, ever.
- **Después:** one optional 20-minute after-spot on every ronda card.
- **Attendance:** the host taps who came ("vino / no vino"). No check-in codes.
- **Buddy check-in:** after one miss without "esta no", only the chosen person gets "Graciela no
  vino el jueves. Te eligió a vos para estas cosas. ¿Le escribís?" [Le escribo] opens an empty
  WhatsApp chat. The absent member never learns the app asked. No escalation, no family.

## First visit
- **Así va a ser** (two days before): how to get there by landmarks, who's coming and what they
  bring, the first five minutes, "Si te querés ir antes: decí 'me tengo que ir' y listo."
- **A named member waits:** the host is asked "¿Quién espera a Nico en el quiosco a las 15:50?";
  the newcomer sees "Te espera Jorge — tiene el termo verde."
- **Spot photo** the day before, 18:00, confirmed members only; SAM 3.1 outlines the bench,
  passers-by blurred. "No los encuentro" pings the host, never shares numbers.
- **Weeks 2–3:** before RSVP closes, the host (not the newcomer) gets "¿Viene Nico?".
- **¿Seguimos?** after meeting 1, private: "¿Seguimos los sábados? Solo Ronda ve tu respuesta."
  4 of 6 yes sets the season (owner may change to 5); a "no" gets "Gracias por venir" and two
  nearby alternatives; their seat reopens.

## Organiser agent (what members see)
- Rain: Wednesday 18:00 to the host only: "Jueves 16:00: lluvia 80% y ráfagas de 50 km/h. ¿Qué
  hacemos?" [Club Solymar] [Viernes] [Igual]; members get one message with the decision.
- Sunset and last bus on every card in winter; agent suggests starting before 17:00 June–August.
- **Ronda se calla:** from week 2, jobs move to members ("Desde ahora Jorge avisa si llueve"):
  the agent drafts, the member sends from their own WhatsApp.
- **El acta:** "Lo que hizo el bot" — a short, factual weekly log; [Algo estuvo mal].
- Voice: first message says "Soy un programa". Logistics only. Never 21:00–09:00.

## Cerca tuyo (public, no login)
- Rows: activity · barrio · time band · age band · seats left; waitlists shown as demand ("9
  vecinos esperan fútbol en Lagomar"). No pins, no exact spots, no names except the host's first
  name on a seat's page. Exact spot only to confirmed members, the day before.

## Flyers
- **Tear-off:** lost-pet format, each tab's QR tied to where the flyer hangs; landing shows only
  rondas within walking distance of that spot and that stop's last bus. Phone number answered by
  a person (later). "Ronda nunca pide plata" printed.
- **Un mate de más:** from week 4 each ronda keeps one newcomer seat. The host photographs the
  group's things (no people): faces blurred on the phone → SAM 3.1 cuts out termo, mazo, mates →
  Muse Image makes the background; "Hay un mate de más. Es tuyo." and the QR are drawn in code.
  Phone app only (no face detection on web): the web app says "Hacelo desde la app del
  teléfono".

## Truco (if kept)
- 3 v 3, under-30 paired with over-60 where both exist, partners rotate weekly, the +1 stays on
  the friend's team. Sold as a campeonato, never "intergenerational".

## Safety
- Reportar (voice or text) → Ciro's queue, tags (money request, harassment, romantic pressure,
  a minor, a private place); reported in two rondas → top. Report-apart pairs never seated
  together. The agent may only move a ronda to a public place in OSM, host confirms.
- Public places, adults only. Helpline in Ajustes: Línea de Prevención del Suicidio 0800 0767 /
  *0767, 911.

## Demo video
The script, shot list and the 45-second X cut are in `docs/DEMO.md`.
