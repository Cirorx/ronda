/// The language a person picked for Ronda on this phone. With none picked,
/// the app follows the phone's own language.
enum AppLanguage {
  /// Rioplatense Spanish.
  spanish('es'),

  /// English.
  english('en');

  new(this.id);

  /// The stored id (`es`).
  final String id;

  /// The language stored as [id], or `null` for an unknown id.
  static AppLanguage? fromId(Object? id) => _byId[id];

  static final Map<String, AppLanguage> _byId = {
    for (final language in values) language.id: language,
  };
}
