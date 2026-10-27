/// One thing a member brings or teaches ("lo que traés"). It is how people
/// are known in their ronda; money is never one of them.
enum Bring {
  /// Pan.
  pan('pan'),

  /// Yerba.
  yerba('yerba'),

  /// Termo.
  termo('termo'),

  /// Sillas.
  sillas('sillas'),

  /// Enseño truco.
  ensenoTruco('enseno-truco'),

  /// Tengo ganas: nothing to bring, just coming.
  tengoGanas('tengo-ganas');

  new(this.id);

  /// The stored id (`termo`).
  final String id;

  /// The item stored as [id], or `null` for an unknown id.
  static Bring? fromId(String id) => _byId[id];

  static final Map<String, Bring> _byId = {
    for (final bring in values) bring.id: bring,
  };
}
