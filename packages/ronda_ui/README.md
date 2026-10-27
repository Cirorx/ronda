# ronda_ui

Ronda's theme tokens and shared components, built on Material 3. Tokens come from
`docs/DESIGN.md` and the component sheet; widgets take every label as a `String`
parameter, so the app owns the copy (`context.l10n`).

```dart
import 'package:ronda_ui/ronda_ui.dart';

MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark, home: ...);
```

## Theme

| Class | Holds |
|---|---|
| `AppColors` | Every colour token, day and night. Read only by the theme. |
| `AppTheme` | `light` / `dark` `ThemeData`: two `ColorScheme`s and every component theme. |
| `RondaPalette` | `ThemeExtension` for roles Material has no slot for (`context.rondaPalette`). |
| `AppTextStyle` | Young Serif titles, Atkinson Hyperlegible text, tabular figures; fills `TextTheme`. |
| `AppSpacing` | 4 / 8 / 12 / 16 / 24 / 32 from a unit of 16 (`context.appSpacing`). |
| `AppRadius` | 8 / 10 / 12 / 16 / 22. |

## Components

`NoteBanner`, `ChipPicker`, `SlotGrid`, `ReadBackCard`, `StepSheet`, `TermsNote`,
`PersonRow`, `SeatRow`, `RsvpBar`. Every tappable part carries a `Semantics` identifier
(`<identifier>.<part>`) for Maestro and a 48 dp target. Every component holds at 200% text;
from `AppTheme.largeTextScale` (1.5) layouts take their large-text form
(`context.usesLargeText`).

## Fonts

Bundled in `assets/fonts/` (OFL 1.1, from github.com/google/fonts): Young Serif Regular and
Atkinson Hyperlegible Regular and Bold. Call `registerRondaUiLicenses()` once from the app's
bootstrap to put both OFL notices on the licence page.

## Tests

Run through the Very Good CLI MCP `test` tool. `test/flutter_test_config.dart` loads the real
fonts, so goldens show real glyphs; regenerate them with `tags: golden, update_goldens: true`.
The Widgetbook catalog in `widgetbook/` shows each component in both themes; its index was
written by hand and should be regenerated with `build_runner` after `flutter pub get` there.
