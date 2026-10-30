import 'package:ronda_repository/ronda_repository.dart';

/// Invented weeks for the Mi ronda tests: a Saturday afternoon mate ronda
/// on 31/10, Raúl already going.
abstract final class MyRondaFixtures {
  static const uid = 'demo-001';

  static ThisWeek week({
    RsvpAnswer? myAnswer,
    List<String> myBrings = const ['pan'],
    List<GoingNeighbour> going = const [
      GoingNeighbour(uid: 'demo-002', firstName: 'Raúl', brings: ['termo']),
    ],
    int noCount = 1,
    int unansweredCount = 2,
    String? placeName,
    String? placeLandmark,
    String? hour,
    Host? anfitrion,
    Host? cola,
    DateTime? pausedUntil,
    bool withView = true,
  }) => ThisWeek(
    rondaId: 'r1',
    pretextId: 'mate',
    barrioId: 'el-pinar-sur',
    slotDayId: 'sat',
    slotBandId: 'afternoon',
    myBrings: myBrings,
    placeName: placeName,
    placeLandmark: placeLandmark,
    hour: hour,
    anfitrion: anfitrion,
    cola: cola,
    week: withView ? '2026-W44' : null,
    date: withView ? DateTime(2026, 10, 31) : null,
    myAnswer: myAnswer,
    pausedUntil: pausedUntil,
    going: withView ? going : const [],
    noCount: withView ? noCount : null,
    unansweredCount: withView ? unansweredCount : null,
  );

  static Seguimos seguimos({
    bool open = true,
    SeguimosAnswer? myAnswer,
    SeguimosOutcome? outcome,
    List<NearbyRonda> alternatives = const [],
    SeguimosChoice? choice,
    bool withWait = true,
  }) => Seguimos(
    rondaId: 'r1',
    slotDayId: 'tue',
    open: open,
    myAnswer: myAnswer,
    outcome: outcome,
    seasonEnd: outcome == SeguimosOutcome.season
        ? DateTime(2026, 11, 24)
        : null,
    alternatives: alternatives,
    floor: outcome == SeguimosOutcome.didntFill ? 4 : null,
    waitUntil: withWait ? DateTime(2026, 11, 16) : null,
    waitStart: withWait ? DateTime(2026, 11, 17) : null,
    choice: choice,
  );

  static final nearby = NearbyRonda(
    rondaId: 'r2',
    pretextId: 'truco',
    barrioId: 'el-pinar-norte',
    slotDayId: 'thu',
    slotBandId: 'afternoon',
    placesLeft: 2,
    next: DateTime(2026, 11, 5),
  );

  /// Eva's offer of the seat Ana freed in a Thursday mate ronda: the meeting
  /// on 5/11 at 16:00, answer by Wednesday 4/11 at 12:00 (local).
  static BenchOffer offer({
    BenchOfferStatus status = BenchOfferStatus.pending,
    String? placeName = 'frente al quiosco',
    String? placeLandmark = 'al lado de la parada',
    DateTime? deadline,
    DateTime? date,
  }) => BenchOffer(
    offerId: 'r1_2026-W45_01',
    rondaId: 'r1',
    date: date ?? DateTime(2026, 11, 5),
    pretextId: 'mate',
    slotDayId: 'thu',
    slotBandId: 'afternoon',
    deadline: deadline ?? DateTime(2026, 11, 4, 12),
    status: status,
    hour: '16:00',
    placeName: placeName,
    placeLandmark: placeLandmark,
  );

  /// Five waiting for mate on Saturday afternoons, six needed, the round
  /// ending on Sunday 1/11 and the ronda starting on Saturday 7/11.
  static Waiting waiting({
    WaitingStatus status = WaitingStatus.open,
    int count = 5,
    NearbyRonda? nearby,
    WaitlistChoice? choice,
  }) => Waiting(
    pretextId: 'mate',
    barrioId: 'el-pinar-sur',
    slotDayId: 'sat',
    slotBandId: 'afternoon',
    count: count,
    threshold: 6,
    deadline: DateTime(2026, 11),
    start: DateTime(2026, 11, 7),
    status: status,
    nearby: nearby,
    choice: choice,
  );
}
