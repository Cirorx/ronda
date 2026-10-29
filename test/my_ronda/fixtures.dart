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
}
