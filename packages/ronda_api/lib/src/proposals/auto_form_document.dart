/// {@template auto_form_document}
/// `config/auto_form`: whether rondas form themselves, and how long the
/// admin has to stop a proposal before it approves itself
/// (`functions/auto_form.py`).
/// {@endtemplate}
class const AutoFormDocument({
  /// Whether the `auto_form` job forms and approves rondas.
  final bool enabled = defaultEnabled,

  /// Minutes between a proposal and its approval; 0 approves at once.
  final int holdMinutes = defaultHoldMinutes,
}) {
  /// {@macro auto_form_document}
  this;

  /// Reads the document's [json] data, `null` when it doesn't exist; a
  /// field that is missing or of another shape reads as its default, as
  /// the server reads it.
  factory fromJson(Map<String, Object?>? json) => AutoFormDocument(
    enabled: switch (json?['enabled']) {
      final bool enabled => enabled,
      _ => defaultEnabled,
    },
    holdMinutes: switch (json?['holdMinutes']) {
      final int hold when hold >= 0 && hold <= maxHoldMinutes => hold,
      _ => defaultHoldMinutes,
    },
  );

  /// The server's default switch, while nobody set one.
  static const defaultEnabled = true;

  /// The server's default hold, in minutes.
  static const defaultHoldMinutes = 60;

  /// The longest hold the server takes: a day.
  static const int maxHoldMinutes = 24 * 60;
}
