# UI design direction (recommendation, 2026-10-26)

**Direction: the barrio's own paper.** Ronda should look like a notice at the almacén, the
ruled sign-up sheet and a tear-off flyer, not like a social app. The flyers, the printed planilla
and the app then read as one thing. The screen canvas (59 phone screens, link in `notes/HANDOFF.md`,
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

Dark mode follows the system (Facu at night): paper `#0E1320`, ink `#E5E9F1`, birome `#93A6FF`,
yerba `#5CC48E`, ámbar `#E2A53D`. Define every colour as a token in both.

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
   motion.

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
