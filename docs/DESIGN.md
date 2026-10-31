# UI design direction (recommendation, 2026-10-26)

**Direction: the barrio's own paper.** Ronda should look like a notice at the almacén, the
ruled sign-up sheet and a tear-off flyer, not like a social app. The flyers, the printed planilla
and the app then read as one thing. The screen canvas (link in `notes/HANDOFF.md`,
local only) is the visual spec; the older planilla mockups (`notes/planilla/index.html`) show the
research.

## Tokens

| Token | Hex (light) | Use |
|---|---|---|
| paper | `#FFFEFA` | background |
| ink | `#18202F` | text |
| birome | `#2341C0` | primary action, links, what neighbours read |
| yerba | `#1D7448` | confirmed, "vino", "seguimos" |
| ámbar | `#985E00` | warnings, rain moves |
| margen | `#C8433C` | rare accents only (the ruled-sheet margin line); never for errors alone |
| line | `#D6DDE8` | dividers |
| muted | `#5A6477` | secondary text |
| surface | `#FFFFFF` | cards on paper |
| danger | `#B42318` | only the "Dejar Ronda y borrar todo" button |
| birome tint · ámbar tint · yerba tint · neutral tint | `#EEF1FC` · `#FBF3E6` · `#E8F3EC` · `#F3F5FA` | NoteBanner backgrounds (info, warning, kept-on-phone, offline) and selected chips |

Dark mode follows the system (Facu at night): paper `#0E1320`, surface `#151B2B`, ink `#E5E9F1`,
birome `#93A6FF`, yerba `#5CC48E`, ámbar `#E2A53D`, margen `#E07A72`, line `#2E384D`, muted
`#A3ADBF`, birome tint `#1C2440`. Define every colour as a token in both. The component sheet on
the screen canvas shows each token and component.

Added by the motion pass (2026-10-30): shadow and scrim are ink by day and `#05070C` at night.

Added by the `ronda_ui` build (2026-10-27): birome pressed `#1A3196`, neutral fill `#EEF0F4`,
control off (switch track) `#8792A6`; dark values derived by mixing over dark paper: danger
`#F07C72`, ámbar tint `#2A2416`, yerba tint `#15291F`, neutral tint `#1A2234`, birome pressed
`#7189F0`, neutral fill `#1F2638`, control off `#6B7489` (confirmed by the owner 2026-10-27). Radii 8/10/12/16/22.
Selected chips show a check as well as colour (colour alone fails WCAG 1.4.1). The time grid
turns into per-day chips from 1.5× text.

Type: **Young Serif** for titles only; **Atkinson Hyperlegible** for everything else (designed for
low-vision readers). Body 17–18 sp. Tabular figures for times. Spacing 4/8/12/16/24/32; card
radius 12; buttons radius 12, height ≥ 48 dp.

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
| `AppMotion.crossFade` | 150 ms, `Easing.standard` | what replaces a slide or a spring under reduced motion |
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
  on from where the last question's stood). A seat filling and a slot being marked use them.
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
  (`ReadableColumn`). Cerca, Ajustes, the terms, sign-in and the payoff use it as it is; the
  welcome screen still stretches (its doors sit at the bottom of the window, and a short window
  would push them out of view). Sheets were already capped at 640.
- **Two columns, never a feed.** On expanded, `PaperColumns` puts the screen's own content in the
  readable column and 360 of context beside it; each column scrolls on its own and keyboard focus
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
  them in the app (a caminata and "Tengo ganas" have none). They are decoration: screen readers skip
  them and large text drops them.
- **Keyboard and mouse.** A button focused from a keyboard gets a 3 dp ring (paper inside a filled
  button, birome on the others); touch never focuses a button that way. Hover comes only from a
  pointer that hovers. Escape closes a dismissible sheet, focus stays inside it, and Enter presses
  the focused button. The rail keeps the bar's press feedback and comes before the content in focus
  order.
- **Onboarding's bar.** The progress bar keeps to the column's width too.
- **Tests** check the shell, onboarding, Mi ronda and the admin screens at 360, 800 and 1280, and
  each at 200% text at 1280.

## In Flutter
- Packages, versions, l10n setup and the native checklist: `docs/STACK.md`. State is Bloc
  (Cubit-first); fonts are bundled, not fetched.
- Theme lives in `packages/ronda_ui` (VGV `app_ui_package`): `AppTheme.light` / `.dark` built
  from the tokens above, a `RondaPalette` ThemeExtension for yerba, ámbar and margen, and
  `AppSpacing`. Widgets read the theme; colours and text styles never appear inline
  (`docs/STACK.md` § Theme and copy).
- Components to build on day 1: `RondaCard`, `PersonRow` (initial, name, age band, what they
  bring), `RsvpBar`, `SeatRow`, `NoteBanner` (info / warning), `ChipPicker`, `SlotGrid`,
  `ReadBackCard`, `TermsNote` (the "Al seguir, aceptás…" line and its link), `StepSheet` (bottom sheet), `AdminProposalCard`.

## Tooling and scope for 9 days
- Skip Figma: the screen canvas is the spec; build the components directly.
- Muse Image is for flyers (creative bonus), not for app chrome.
- Make the public pages (Cerca tuyo, QR landing) plain HTML on Firebase Hosting: they load fast
  on old phones and slow connections, where a Flutter web bundle is heavy. The member app stays
  Flutter.
- Polish three hero screens for the video: voice read-back, Mi ronda card, the flyer.
