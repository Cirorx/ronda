/// Where a barrio is: the picker groups them by it.
enum BarrioArea {
  /// Ciudad de la Costa, in Canelones.
  costa,

  /// Montevideo.
  montevideo,
}

/// The barrios Ronda forms rondas in: Ciudad de la Costa's nine and
/// Montevideo's 62 (the INE's). Distance is measured between barrio
/// centroids, so only the barrio is ever asked, never an address.
///
/// The ids and names are the server's (`solver/ronda_solver/barrios.py`; a
/// test in `scripts/tests` keeps the two in step). Names are proper nouns,
/// the same in every language, so they live here and not in the app's l10n.
/// Montevideo's are in alphabetical order.
enum Barrio {
  /// Shangrilá.
  shangrila('shangrila', 'Shangrilá', BarrioArea.costa),

  /// San José de Carrasco.
  sanJoseDeCarrasco(
    'san-jose-de-carrasco',
    'San José de Carrasco',
    BarrioArea.costa,
  ),

  /// Lagomar Sur.
  lagomarSur('lagomar-sur', 'Lagomar Sur', BarrioArea.costa),

  /// Lagomar Norte.
  lagomarNorte('lagomar-norte', 'Lagomar Norte', BarrioArea.costa),

  /// Solymar Sur.
  solymarSur('solymar-sur', 'Solymar Sur', BarrioArea.costa),

  /// Solymar Norte.
  solymarNorte('solymar-norte', 'Solymar Norte', BarrioArea.costa),

  /// Lomas de Solymar.
  lomasDeSolymar('lomas-de-solymar', 'Lomas de Solymar', BarrioArea.costa),

  /// El Pinar Sur.
  elPinarSur('el-pinar-sur', 'El Pinar Sur', BarrioArea.costa),

  /// El Pinar Norte.
  elPinarNorte('el-pinar-norte', 'El Pinar Norte', BarrioArea.costa),

  /// Aguada.
  aguada('aguada', 'Aguada', BarrioArea.montevideo),

  /// Aires Puros.
  airesPuros('aires-puros', 'Aires Puros', BarrioArea.montevideo),

  /// Atahualpa.
  atahualpa('atahualpa', 'Atahualpa', BarrioArea.montevideo),

  /// Bañados de Carrasco.
  banadosDeCarrasco(
    'banados-de-carrasco',
    'Bañados de Carrasco',
    BarrioArea.montevideo,
  ),

  /// Barrio Sur.
  barrioSur('barrio-sur', 'Barrio Sur', BarrioArea.montevideo),

  /// Belvedere.
  belvedere('belvedere', 'Belvedere', BarrioArea.montevideo),

  /// Brazo Oriental.
  brazoOriental('brazo-oriental', 'Brazo Oriental', BarrioArea.montevideo),

  /// Buceo.
  buceo('buceo', 'Buceo', BarrioArea.montevideo),

  /// Capurro y Bella Vista.
  capurroBellaVista(
    'capurro-bella-vista',
    'Capurro y Bella Vista',
    BarrioArea.montevideo,
  ),

  /// Carrasco.
  carrasco('carrasco', 'Carrasco', BarrioArea.montevideo),

  /// Carrasco Norte.
  carrascoNorte('carrasco-norte', 'Carrasco Norte', BarrioArea.montevideo),

  /// Casabó y Pajas Blancas.
  casaboPajasBlancas(
    'casabo-pajas-blancas',
    'Casabó y Pajas Blancas',
    BarrioArea.montevideo,
  ),

  /// Casavalle.
  casavalle('casavalle', 'Casavalle', BarrioArea.montevideo),

  /// Castro y Pérez Castellanos.
  castroPerezCastellanos(
    'castro-perez-castellanos',
    'Castro y Pérez Castellanos',
    BarrioArea.montevideo,
  ),

  /// Centro.
  centro('centro', 'Centro', BarrioArea.montevideo),

  /// Cerrito.
  cerrito('cerrito', 'Cerrito', BarrioArea.montevideo),

  /// Cerro.
  cerro('cerro', 'Cerro', BarrioArea.montevideo),

  /// Ciudad Vieja.
  ciudadVieja('ciudad-vieja', 'Ciudad Vieja', BarrioArea.montevideo),

  /// Colón Centro y Noroeste.
  colonCentroNoroeste(
    'colon-centro-noroeste',
    'Colón Centro y Noroeste',
    BarrioArea.montevideo,
  ),

  /// Colón Sureste y Abayubá.
  colonSuresteAbayuba(
    'colon-sureste-abayuba',
    'Colón Sureste y Abayubá',
    BarrioArea.montevideo,
  ),

  /// Conciliación.
  conciliacion('conciliacion', 'Conciliación', BarrioArea.montevideo),

  /// Cordón.
  cordon('cordon', 'Cordón', BarrioArea.montevideo),

  /// Flor de Maroñas.
  florDeMaronas('flor-de-maronas', 'Flor de Maroñas', BarrioArea.montevideo),

  /// Ituzaingó.
  ituzaingo('ituzaingo', 'Ituzaingó', BarrioArea.montevideo),

  /// Jacinto Vera.
  jacintoVera('jacinto-vera', 'Jacinto Vera', BarrioArea.montevideo),

  /// Jardines del Hipódromo.
  jardinesDelHipodromo(
    'jardines-del-hipodromo',
    'Jardines del Hipódromo',
    BarrioArea.montevideo,
  ),

  /// La Blanqueada.
  laBlanqueada('la-blanqueada', 'La Blanqueada', BarrioArea.montevideo),

  /// La Comercial.
  laComercial('la-comercial', 'La Comercial', BarrioArea.montevideo),

  /// La Figurita.
  laFigurita('la-figurita', 'La Figurita', BarrioArea.montevideo),

  /// La Paloma y Tomkinson.
  laPalomaTomkinson(
    'la-paloma-tomkinson',
    'La Paloma y Tomkinson',
    BarrioArea.montevideo,
  ),

  /// La Teja.
  laTeja('la-teja', 'La Teja', BarrioArea.montevideo),

  /// Larrañaga.
  larranaga('larranaga', 'Larrañaga', BarrioArea.montevideo),

  /// Las Acacias.
  lasAcacias('las-acacias', 'Las Acacias', BarrioArea.montevideo),

  /// Las Canteras.
  lasCanteras('las-canteras', 'Las Canteras', BarrioArea.montevideo),

  /// Lezica y Melilla.
  lezicaMelilla('lezica-melilla', 'Lezica y Melilla', BarrioArea.montevideo),

  /// Malvín.
  malvin('malvin', 'Malvín', BarrioArea.montevideo),

  /// Malvín Norte.
  malvinNorte('malvin-norte', 'Malvín Norte', BarrioArea.montevideo),

  /// Manga.
  manga('manga', 'Manga', BarrioArea.montevideo),

  /// Manga y Toledo Chico.
  mangaToledoChico(
    'manga-toledo-chico',
    'Manga y Toledo Chico',
    BarrioArea.montevideo,
  ),

  /// Maroñas y Parque Guaraní.
  maronasParqueGuarani(
    'maronas-parque-guarani',
    'Maroñas y Parque Guaraní',
    BarrioArea.montevideo,
  ),

  /// Mercado Modelo y Bolívar.
  mercadoModeloBolivar(
    'mercado-modelo-bolivar',
    'Mercado Modelo y Bolívar',
    BarrioArea.montevideo,
  ),

  /// Nuevo París.
  nuevoParis('nuevo-paris', 'Nuevo París', BarrioArea.montevideo),

  /// Palermo.
  palermo('palermo', 'Palermo', BarrioArea.montevideo),

  /// Parque Batlle y Villa Dolores.
  parqueBatlleVillaDolores(
    'parque-batlle-villa-dolores',
    'Parque Batlle y Villa Dolores',
    BarrioArea.montevideo,
  ),

  /// Parque Rodó.
  parqueRodo('parque-rodo', 'Parque Rodó', BarrioArea.montevideo),

  /// Paso de la Arena.
  pasoDeLaArena('paso-de-la-arena', 'Paso de la Arena', BarrioArea.montevideo),

  /// Paso de las Duranas.
  pasoDeLasDuranas(
    'paso-de-las-duranas',
    'Paso de las Duranas',
    BarrioArea.montevideo,
  ),

  /// Peñarol y Lavalleja.
  penarolLavalleja(
    'penarol-lavalleja',
    'Peñarol y Lavalleja',
    BarrioArea.montevideo,
  ),

  /// Piedras Blancas.
  piedrasBlancas('piedras-blancas', 'Piedras Blancas', BarrioArea.montevideo),

  /// Pocitos.
  pocitos('pocitos', 'Pocitos', BarrioArea.montevideo),

  /// Prado y Nueva Savona.
  pradoNuevaSavona(
    'prado-nueva-savona',
    'Prado y Nueva Savona',
    BarrioArea.montevideo,
  ),

  /// Punta Carretas.
  puntaCarretas('punta-carretas', 'Punta Carretas', BarrioArea.montevideo),

  /// Punta de Rieles y Bella Italia.
  puntaDeRielesBellaItalia(
    'punta-de-rieles-bella-italia',
    'Punta de Rieles y Bella Italia',
    BarrioArea.montevideo,
  ),

  /// Punta Gorda.
  puntaGorda('punta-gorda', 'Punta Gorda', BarrioArea.montevideo),

  /// Reducto.
  reducto('reducto', 'Reducto', BarrioArea.montevideo),

  /// Sayago.
  sayago('sayago', 'Sayago', BarrioArea.montevideo),

  /// Tres Cruces.
  tresCruces('tres-cruces', 'Tres Cruces', BarrioArea.montevideo),

  /// Tres Ombúes y Pueblo Victoria.
  tresOmbuesPuebloVictoria(
    'tres-ombues-pueblo-victoria',
    'Tres Ombúes y Pueblo Victoria',
    BarrioArea.montevideo,
  ),

  /// Unión.
  union('union', 'Unión', BarrioArea.montevideo),

  /// Villa Española.
  villaEspanola('villa-espanola', 'Villa Española', BarrioArea.montevideo),

  /// Villa García y Manga Rural.
  villaGarciaMangaRural(
    'villa-garcia-manga-rural',
    'Villa García y Manga Rural',
    BarrioArea.montevideo,
  ),

  /// Villa Muñoz y Retiro.
  villaMunozRetiro(
    'villa-munoz-retiro',
    'Villa Muñoz y Retiro',
    BarrioArea.montevideo,
  );

  new(this.id, this.label, this.area);

  /// The stored id (`solymar-norte`). Never contains `_`: seat ids join
  /// barrio, pretext and slot with it.
  final String id;

  /// What the app shows ("Solymar Norte").
  final String label;

  /// Where the barrio is.
  final BarrioArea area;

  /// The barrio stored as [id], or `null` for an unknown id.
  static Barrio? fromId(String? id) => _byId[id];

  static final Map<String, Barrio> _byId = {
    for (final barrio in values) barrio.id: barrio,
  };
}
