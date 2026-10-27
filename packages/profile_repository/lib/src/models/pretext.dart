/// What a ronda does ("actividad").
enum Pretext {
  /// Mate en la rambla.
  mate('mate'),

  /// Truco.
  truco('truco'),

  /// Fútbol 5.
  futbol5('futbol5'),

  /// Caminata.
  caminata('caminata');

  new(this.id);

  /// The stored id (`mate`), the same one the solver reads.
  final String id;

  /// The pretext stored as [id], or `null` for an unknown id.
  static Pretext? fromId(String id) => _byId[id];

  static final Map<String, Pretext> _byId = {
    for (final pretext in values) pretext.id: pretext,
  };
}
