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
}
