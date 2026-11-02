/// One thing a member brings or teaches ("lo que traés"). It is how people
/// are known in their ronda; money is never one of them.
enum Bring {
  /// Pan.
  pan('pan'),

  /// Yerba.
  yerba('yerba'),

  /// El mate: the mate and the termo together. The id stays `termo`, so
  /// profiles saved before the label changed keep their choice.
  termo('termo'),

  /// Sillas.
  sillas('sillas'),

  /// Enseño truco.
  ensenoTruco('enseno-truco'),

  /// Tortas fritas, on a rainy day only.
  tortasFritas('tortas-fritas'),

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
