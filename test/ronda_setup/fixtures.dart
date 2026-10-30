import 'package:ronda_repository/ronda_repository.dart';

/// Invented rondas for the admin's setup screen.
abstract final class SetupFixtures {
  static const members = [
    SetupMember(uid: 'demo-103', firstName: 'Ana'),
    SetupMember(uid: 'demo-102', firstName: 'Jorge'),
    SetupMember(uid: 'demo-101', firstName: 'Mirta'),
  ];

  /// A Thursday-afternoon mate ronda as approval leaves it: nothing set.
  static const bare = RondaSetup(
    rondaId: 'r1',
    pretextId: 'mate',
    barrioId: 'el-pinar-sur',
    slotDayId: 'thu',
    slotBandId: 'afternoon',
    members: members,
  );

  /// The same ronda once the admin set it up, with its latest roll.
  static final set = RondaSetup(
    rondaId: 'r1',
    pretextId: 'mate',
    barrioId: 'el-pinar-sur',
    slotDayId: 'thu',
    slotBandId: 'afternoon',
    members: members,
    hour: '16:00',
    placeName: 'Frente al quiosco',
    placeLandmark: 'al lado de la parada',
    anfitrionUid: 'demo-101',
    colaUid: 'demo-102',
    roll: RollSummary(
      week: '2026-W45',
      date: DateTime(2026, 11, 5),
      people: 3,
      marked: 1,
    ),
  );
}
