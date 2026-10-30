import 'package:ronda_ui/ronda_ui.dart';

export 'haptics.dart';
export 'pump_app.dart';
export 'test_tag.dart';

/// Both themes, named, for tests that run in day and night.
final themes = <String, ThemeData Function()>{
  'light': () => AppTheme.light,
  'dark': () => AppTheme.dark,
};

/// The text scales every component is checked at.
const textScales = <double>[1, 1.3, 2];
