/// The only age data Ronda keeps: a band the person picks ("sesenta y
/// pico"), never a birth date.
enum AgeBand {
  /// 18 to 29.
  from18To29('18-29'),

  /// 30 to 39.
  thirties('30-39'),

  /// 40 to 49.
  forties('40-49'),

  /// 50 to 59.
  fifties('50-59'),

  /// 60 to 69.
  sixties('60-69'),

  /// 70 to 79.
  seventies('70-79'),

  /// 80 and over.
  eightyPlus('80+');

  new(this.id);

  /// The stored id (`60-69`), the same one the solver reads.
  final String id;

  /// The band stored as [id], or `null` for an unknown id.
  static AgeBand? fromId(String? id) => _byId[id];

  static final Map<String, AgeBand> _byId = {
    for (final band in values) band.id: band,
  };
}
