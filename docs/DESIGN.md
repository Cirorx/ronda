# UI design direction (recommendation, 2026-10-26)

**Direction: the barrio's own paper.** Ronda should look like a notice at the almacén, the
ruled sign-up sheet and a tear-off flyer, not like a social app. The flyers, the printed planilla
and the app then read as one thing. The screens in the app are the visual spec.

## Tokens

Mate y alpaca (chosen 2026-11-03): the camionero gourd — dusty yerba, dark
solemn brown, alpaca silver, the ochre inside of the shell. Crafted, grounded,
most tactile. Roundest radius (20), Zilla Slab titles + Atkinson Hyperlegible
text. The token *names* are the roles and predate the direction: `birome` is
the primary action (now yerba green, not blue), `yerba` the tertiary (now
alpaca silver), `margen` the margin line (now ochre).

| Token | Hex (light) | Hex (dark) | Use |
|---|---|---|---|
| paper | `#F8F3EA` | `#171310` | background |
| surface | `#FFFFFF` | `#241D17` | cards on paper |
| ink | `#241B12` | `#F5EEDF` | text |
| muted | `#77695A` | `#BCAF9C` | secondary text |
| line | `#E2D6C2` | `#42362A` | dividers |
| primary (`birome`) | `#4E6428` | `#C2D191` | primary action, links, what neighbours read |
| primary pressed | `#3E5020` | `#A9BC74` | primary while pressed |
| accent (`ambar`) | `#8F5E0B` | `#EBC078` | warnings, rain moves |
| tertiary (`yerba`) | `#5C6B7A` | `#BEC9D4` | confirmed, "vino", "seguimos" |
| margen | `#8F5E0B` | `#EBC078` | the ruled sheet's margin line; never for errors alone |
| danger | `#B42318` | `#F07C72` | only the "Dejar Ronda y borrar todo" button |
| birome tint | `#EEF1DF` | `#2E3419` | info banners, selected chips, offline banners, segmented track |
| ámbar tint | `#FAF0DA` | `#3D2E14` | warning banners |
| yerba tint | `#E9EDF0` | `#2A333C` | kept-on-phone banners |

Dark mode follows the system (Facu at night).

Added by the motion pass (2026-10-30): shadow and scrim are ink by day and `#05070C` at night.

Added by the `ronda_ui` build (2026-10-27, re-hued 2026-11-03 for Mate y alpaca):
pressed `#3E5020` / `#A9BC74`, neutral fill and offline tint = the primary tint,
switch off = muted. Radii 8/10/20/16/22 (buttons, cards and banners take 20).
Selected chips show a check as well as colour (colour alone fails WCAG 1.4.1). The time grid
turns into per-day chips from 1.5× text.

Type: **Zilla Slab** (Medium 500 book weight, SemiBold 600, Bold 700) for
titles; **Atkinson Hyperlegible** for everything else (designed for
low-vision readers). Body 17–18 sp. Tabular figures for times. Spacing 4/8/12/16/24/32; card
radius 20; buttons radius 20, height ≥ 48 dp.

## Principles
1. **Design for Graciela and Facu at once.** Large type, high contrast (birome on paper ≈ 8:1),
   system text scale up to 200%, 48 dp targets, voice as an option and three taps as the other.
2. **Most of the UI isn't in the app.** The Tuesday push with [Voy] [Esta no], the WhatsApp link
   and the paper flyers are the product. Design their copy and actions first.
3. **One card, no feed.** Home is this week's ronda card. Tabs: Mi ronda, Cerca, Ajustes. No badge
   counts, no streaks, no red dots, no infinite scroll.
4. **Objects, not people.** A small line-icon set of ronda objects (mate, termo, pelota, mazo,
   bizcochos, sillas) doubles as "lo que traés" and as flyer art. People are initials.
5. **Copy is the interface.** Voseo, short, verb first; never the word "IA". "Ronda nunca pide
   plata" is said where it earns its place: the terms ("Ronda es gratis") and the printed
   flyers. App screens and messages, routine pushes included, don't repeat it.
6. **Calm motion.** Only state changes animate (a seat filling, a confirmation); respect reduced
   motion. The values and the rules are in § Motion and feel.

## Motion and feel

Decided with the owner on 2026-10-30: keep the paper look and take the interaction side of
Apple's *Designing Fluid Interfaces*. No glass: no translucent or blurred bars or sheets, and no
`BackdropFilter`. Everything below lives in `packages/ronda_ui`, so screens get it by using the
theme and the shared components.

**Springs** are written as Apple writes them, a damping ratio (1 is no bounce) and a response in
seconds, and converted to Flutter's `SpringDescription` with a mass of 1: stiffness
(2π / response)², damping 4π · ratio / response (`AppMotion.spring`).

| Token | Value | Use |
|---|---|---|
| `AppMotion.standard` | damping 1, response 0.35 s | every state change; a sheet rising, closing or springing back after a slow release |
| `AppMotion.sheet` | damping 0.8, response 0.3 s | a sheet settling after a flick (faster than 300 dp/s); only momentum earns the bounce |
| `AppMotion.standardCurve` / `standardDuration` | the standard spring over 350 ms | widgets that take a curve (`RondaSwap`) |
| `AppMotion.press` / `pressedScale` | 100 ms, 0.97 | press feedback |
| `AppMotion.crossFade` | 150 ms, `Easing.standard` | what replaces a slide or a spring under reduced motion; the scroll edge's fade |
| `AppMotion.hover` | 150 ms | a mouse's hover tint on the surfaces whose ink Ronda builds (slot cell, door, seat card) |
| `AppMotion.project` | Apple's `project()`, deceleration 0.998 | where a throw would land |
| `AppMotion.rubberBand` | constant 0.55 | resistance past an edge |

**Reduced motion.** `RondaMotion.of(context)` reads `MediaQuery.disableAnimationsOf` and is the
one place a widget asks how to move: springs become jumps, slides become a cross-fade, presses
change size at once. Feedback stays; only the travel goes. The phone's own "remove animations"
setting also makes Flutter run every ordinary `AnimationController` at 5% of its duration, which
would turn the 150 ms cross-fade into a cut; `RondaSwap`, `StepSwitcher` and the sheet's route run
theirs with `AnimationBehavior.preserve`, so the cross-fade really lasts 150 ms. Their tests turn
the platform flag on, not only a `MediaQuery` override.

**The rules.**
- *Press on touch-down.* The theme's buttons (`FilledButton`, `OutlinedButton`, `TextButton`,
  `IconButton`) shrink to 0.97, fill, border, ink and label together (`PressedShape` plus the
  style's `foregroundBuilder`), and come back on release or when the finger drags away. Any other
  tappable (a card, a chip, a grid cell, a list row) is wrapped in `PressScale`, which listens to
  the raw pointer and so responds before a tap is recognised. Inside a scroll view Flutter holds
  a tap's touch-down back up to 100 ms (`kPressTimeout`) until it knows the touch isn't a
  scroll; the theme's buttons don't wait for it: they mark themselves pressed on the raw
  touch-down and let go if the touch turns into a scroll, as Apple's rule asks (the ink ripple
  still starts when the tap is recognised). A call site that sets its own `shape:` or
  `backgroundBuilder:` loses that.
- *Sheets are things in the hand.* `showRondaSheet` (and `StepSheet.show`) rise from the bottom
  over an ink scrim at 40%, follow a drag 1:1 from where it was grabbed, rubber-band past the top,
  carry the finger's speed on release, close when the projected landing point is past half
  their height and the finger wasn't moving up, and can be grabbed again mid-flight. They leave
  the way they came. Content that scrolls hands a pull from its top over to the sheet. With
  reduced motion they cross-fade.
- *Every sheet closes the same way.* The handle's row is a 48 dp target: a tap or a click on it
  closes the sheet the way a throw would, and a close button (✕, "Cerrar") sits at the end of
  that row for keyboards and screen readers. Both come from `RondaSheetRoute`, so every sheet
  has them, `StepSheet` included, and no sheet adds its own. A `PopScope` that refuses keeps
  the sheet open, as it does for the scrim; a sheet that isn't dismissible has neither.
- *Same path in and out.* A pushed screen comes in from the right and goes back out to the right,
  with the platform's edge swipe back (`RondaPageTransitionsBuilder`, set for every platform in
  `AppTheme`). Tabs swap in place. Reduced motion cross-fades.
- *Depth stays paper.* The top bar is flat paper until content scrolls under it, then lifts with
  a soft ink shadow (elevation 3, ink at 35%; night uses `#05070C`). No divider under it. Modal
  sheets dim what is behind with the scrim.
- *Only state changes move.* `RondaSwap` swaps one state for the next (fade plus a settle from
  0.96); the state on its way out takes no touches and isn't read, so there is never a second
  copy to tap. `SpringBuilder` follows a value on a spring and retargets mid-flight with its
  speed; given `from:`, a freshly built one springs from there (onboarding's progress bar moving
  on from where the last question's stood). A seat filling uses it, growing and fading in from
  60% of the dot, never from nothing. Marking a slot is instant (fill and check at once): it is
  tapped many times in a row, so it never waits on a 350 ms settle.
  `StepSwitcher` moves between the steps of one page (onboarding's questions) as a pushed
  screen moves, forward and back, without pushing a route.
- *Waiting is said, not spun.* A screen that reads shows `LoadingStatus` (a ring and a line that
  says what it is looking for; `LoadingStatus.inline` in a list); a pressed button whose work is
  on its way shows `BusyLabel` (a ring inside it) and can't be pressed twice; `StatusLine` reads
  the line out as it changes. `RsvpBar` does both for an answer on its way (`pending:`).
- *Haptics only on commits.* `RondaHaptics.onCommit` fires a light impact in the same handler
  that changes the screen, on these and nothing else (checked against the code 2026-10-30):
  - the answers in `RsvpBar`: Voy / Esta no, Lo tomo / Esta vez no (a seat on the bench),
    Sí / No (seguimos);
  - Pausar 2 semanas and Me equivoqué, voy (after "Esta no"; Sigo en la ronda changes nothing,
    so it has none);
  - the waiting and seguimos choices: Sumarte a otro ya / Esperar dos semanas más;
  - Sí, abro yo / Hoy no puedo (the host's handoff), Sí, puede ser / Mejor no (después at
    home), Guardar on the después sheet (only when it will save);
  - Vino / No vino, Algo estuvo mal, Elegir (a buddy; Ahora no has none), Mandarlo (the rain
    move), Hacer el volante, Imprimir o compartir;
  - Está bien, guardalo (the read-back), Sí, avisame, Prender los avisos, Salir;
  - admin: Armar las rondas / Armarlas de nuevo, Aprobar y avisarles, Deshacer, Sumar, Pasar,
    Mandarlo ahora, Guardar (a ronda's place and hour), the rain checks (Correr el chequeo de
    lluvia, Probar a las 22:00).

  Never on toggles, scrolling, navigation, cancels or closing a sheet.
- *Type by size.* Tracking comes from `AppTextStyle.trackingFor`: −0.025 em at 48 sp, −0.018 at
  30, −0.01 at 22, 0 at 17–18 sp body, +0.008 at 15 and +0.015 at 13. Leading is tight on titles
  (1.05–1.2) and comfortable on body (1.45). Every style sets its tracking explicitly, so
  Material's default body tracking (+0.25 px) no longer leaks in. Tabular figures stay.

## Wide screens

Added on 2026-10-30, after the owner tried the web app on a desktop: the screens stretched edge to
edge. Phones are unchanged; every rule below is guarded by the window's width.

| Window | Width | What changes |
|---|---|---|
| compact (`WindowSize.compact`) | below 600 | nothing: the phone layout |
| medium | 600 to 839 | content keeps to a readable column; tabs stay in the bottom bar |
| expanded | 840 and up | the tabs stand in a `NavigationRail`; screens put their context beside the column |

- **Readable column.** Text, forms and cards are at most 600 wide, centred on the paper, with the
  ruled sheet's margin line (margen at the `PersonRow` line's strength) down the start side
  (`ReadableColumn`). Cerca, Ajustes, the terms, sign-in, the payoff and the welcome screen use it
  as it is. On a phone the welcome screen's doors sit at the bottom of the window; wider up they
  sit right under the copy and the two are centred together, scrolling when the window is short.
  Sheets were already capped at 640.
- **Two columns, never a feed.** On expanded, `PaperColumns` puts the screen's own content in the
  readable column and 360 of context beside it, the pair centred in the window as one group; each
  column scrolls on its own and keyboard focus
  goes through the main one first. Wide windows use the room for context, not for bigger controls.
  - Mi ronda: the week's card in the column; "Quiénes van" (initials, and what each brings drawn),
    the buddy and the acta's link beside it.
  - Onboarding: the questions in the column; beside them the chosen pretexts and what the person
    brings, drawn as the ronda's objects. Related questions share a page: what you'd do and what
    you bring, when and where, your age and what makes it hard to go, then your name. One "Seguir"
    moves past the page. With large text even a desktop goes back to one question a page.
  - Admin: the proposal with who it leaves out beside it; the run list with the selected run's
    trace beside it (the trace gets the 600, the list 440); the rondas' setup in one column.
- **Objects, not people.** `RondaObjectIcon` draws mate, termo, pelota, mazo, bizcochos and sillas
  in code on a 24-unit grid with round 1.6 strokes, in birome on paper. Pretexts and brings map to
  them in the app (a caminata, mirar pájaros and "Tengo ganas" have none; conga uses the mazo, merienda and tortas fritas the bizcochos). They are decoration: screen readers skip
  them and large text drops them.
- **Keyboard and mouse.** Anything focused from a keyboard gets a 2 dp ring, birome in both
  themes, at once and never animated. A theme button draws it as its border (paper inside a filled
  button); every other tappable, through `PressScale`, gets `FocusRing` 2 dp outside its edge,
  following its corners (pill for chips, 10 for slot cells, 12 for cards). Like a browser's
  `:focus-visible`, the ring shows only while the last thing done was a key: a tap or a click
  hides it and the next key brings it back. A mouse over a tappable tints it with the theme's
  hover state layer (ink at 8%; `ThemeData.hoverColor`), fading over `AppMotion.hover` where
  Ronda builds the ink and over Flutter's 50 ms inside chips and list rows; touch never hovers, so
  phones never show it. Escape closes a dismissible sheet, focus stays inside it, and Enter presses
  the focused button. The rail keeps the bar's press feedback and comes before the content in focus
  order.
- **Onboarding's bar.** Wider than a phone the back button and the progress bar stand in the
  same column as the questions, with the margin line running up through the bar. While questions
  scroll under "Seguir", a 32 dp fade of the paper sits above it (`ScrollEdgeFade`); at the end of
  the content, or when it all fits, there is none. Phones keep the plain bar and no fade.
- **Tests** check the shell, onboarding, Mi ronda and the admin screens at 360, 800 and 1280, and
  each at 200% text at 1280.

## Sketches

Added on 2026-11-03: the screens that were only words get a small line drawing. `RondaSketch`
(`packages/ronda_ui`) draws each scene in code, in the same line as `RondaObjectIcon`: round
strokes on a 24-unit-tall grid, the icons' own outlines reused where a scene holds a mate, a
termo, a mazo or bizcochos. The geometry scales, the stroke stops at what a 48 dp icon shows
(3.2 dp), so a big sketch still reads as a birome line. Colours come only from the theme:
outlines in muted, yerba green (primary) for what is taken or done, the ochre margen, alpaca
silver (tertiary) for metal, the line colour for rules, the surface for paper.

| Scene | Where | What |
|---|---|---|
| `emptyChairs` | Mi ronda, no group yet | four chairs, one taken in green |
| `termoAsks` | Mi ronda, couldn't read the week | a termo with its cup off, an ochre question mark; no red |
| `almacenNotice` | Cerca | an almacén's door with a ruled notice taped on it |
| `termoStamp` | Mi ronda's card after "Voy" (48 dp) | a termo with a green tick stamped beside it |
| `firstLine` | the payoff, "Sos de los primeros" | a ruled sheet, one line written by the margin |
| `mateServed` | ¿seguimos? closed, "Gracias por venir" (48 dp) | a mate and its bombilla, the ochre inside showing |
| `openCuaderno` | the cuaderno with no lines yet | an open cuaderno, its lines blank, a pencil on it |
| `objectsOnALine` | welcome, beside the doors' heading (28 dp) | mate, termo, mazo and bizcochos on a ruled line |

Onboarding draws no scene: narrower than a desktop, where there is no side column, a row of the
six object icons (28 dp, outline colour) stands over each question. Full-screen sketches are 96
to 112 dp tall, those in cards 48; a sketch shrinks to the room it has and keeps its shape.

Sketches are decoration: screen readers skip them and large text drops them, like the icons.
They don't move. Never people, faces, hands or silhouettes, map pins or maps, confetti,
gradients (the agent's virola thread owns those) or anything about money.

## In Flutter
- Packages, versions, l10n setup and the native checklist: `docs/STACK.md`. State is Bloc
  (Cubit-first); fonts are bundled, not fetched.
- Theme lives in `packages/ronda_ui` (VGV `app_ui_package`): `AppTheme.light` / `.dark` built
  from the tokens above, a `RondaPalette` ThemeExtension for yerba, ámbar and margen, an
  `AiTreatment` ThemeExtension for the agent's virola thread, and `AppSpacing`. Widgets read
  the theme; colours and text styles never appear inline (`docs/STACK.md` § Theme and copy).
- Components to build on day 1: `RondaCard`, `PersonRow` (initial, name, age band, what they
  bring), `RsvpBar`, `SeatRow`, `NoteBanner` (info / warning), `ChipPicker`, `SlotGrid`,
  `ReadBackCard`, `TermsNote` (the "Al seguir, aceptás…" line and its link), `StepSheet` (bottom sheet), `AdminProposalCard`.

## The AI treatment, and when to use it

`AiTreatment` (the virola thread) marks surfaces the organiser agent composed: a
yerba → ochre → silver gradient line along the top of the card (`AiSignature`), with a quiet
label chip naming the agent's work. Light: `#B9C48A → #D9A441 → #C9C2B8`, label ochre on
`#FAF0DA`. Dark: `#C2D191 → #EBC078 → #D8D2C8`, label `#EBC078` on `#3D2E14`.

Use it on exactly these, and nowhere else:

- the weekly card (agent-composed blocks) and Algo chico's suggestions;
- the postcard and the flyer the agent drew;
- auto-formed proposals ("Se aprueba sola a las…").

Anything else that draws a gradient is decoration, not the agent's work. The thread and the
label both pass WCAG 2.2 AA against their card in both modes (checked in
`packages/ronda_ui/test/src/theme/app_theme_test.dart`); the thread itself is decoration and
is skipped by screen readers, while the label is read as ordinary text.

## Tooling and scope for 9 days
- Skip Figma: the screen canvas is the spec; build the components directly.
- Muse Image is for flyers (creative bonus), not for app chrome.
- Make the public pages (Cerca tuyo, QR landing) plain HTML on Firebase Hosting: they load fast
  on old phones and slow connections, where a Flutter web bundle is heavy. The member app stays
  Flutter.
- Polish three hero screens for the video: voice read-back, Mi ronda card, the flyer.
