/// {@template step_named}
/// A cubit or bloc that names itself in error reports.
///
/// A release web build minifies type names (`minified:Ds`), so the observer
/// cannot read the step from `runtimeType`; a string constant survives.
/// {@endtemplate}
abstract interface class StepNamed {
  /// The step an error from this bloc reports: its class name, as a literal.
  String get reportStep;
}
