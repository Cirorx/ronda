/// The barrios of Ciudad de la Costa Ronda forms rondas in. Distance is
/// measured between barrio centroids, so only the barrio is ever asked,
/// never an address.
///
/// The ids are the solver's (`solver/fixtures/invented_demo_30.json`); UI
/// names come from the app's l10n.
enum Barrio {
  /// Shangrilá.
  shangrila('shangrila'),

  /// San José de Carrasco.
  sanJoseDeCarrasco('san-jose-de-carrasco'),

  /// Lagomar Sur.
  lagomarSur('lagomar-sur'),

  /// Lagomar Norte.
  lagomarNorte('lagomar-norte'),

  /// Solymar Sur.
  solymarSur('solymar-sur'),

  /// Solymar Norte.
  solymarNorte('solymar-norte'),

  /// Lomas de Solymar.
  lomasDeSolymar('lomas-de-solymar'),

  /// El Pinar Sur.
  elPinarSur('el-pinar-sur'),

  /// El Pinar Norte.
  elPinarNorte('el-pinar-norte');

  new(this.id);

  /// The stored id (`solymar-norte`). Never contains `_`: seat ids join
  /// barrio, pretext and slot with it.
  final String id;

  /// The barrio stored as [id], or `null` for an unknown id.
  static Barrio? fromId(String? id) => _byId[id];

  static final Map<String, Barrio> _byId = {
    for (final barrio in values) barrio.id: barrio,
  };
}
