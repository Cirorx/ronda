import 'package:ronda_repository/ronda_repository.dart';

/// Invented people for Así va a ser: Nico (demo-105) comes for the first
/// time on Thursday 2026-11-05 at 16:00, frente al quiosco. Mirta
/// (demo-101) opens, Jorge (demo-102) closes, Ana (demo-103) is in.
abstract final class FirstVisitFixtures {
  static const mirta = Host(uid: 'demo-101', firstName: 'Mirta');
  static const jorge = Host(uid: 'demo-102', firstName: 'Jorge');

  static final thursday = DateTime(2026, 11, 5);

  /// Nobody picked: whoever opens waits.
  static final open = Welcome(
    rondaId: 'r1',
    newcomerUid: 'demo-105',
    newcomerName: 'Nico',
    week: '2026-W45',
    date: thursday,
    hour: '16:00',
    placeName: 'frente al quiosco',
    placeLandmark: 'al lado de la parada',
    waiter: mirta,
    choices: const [
      SetupMember(uid: 'demo-103', firstName: 'Ana'),
      SetupMember(uid: 'demo-102', firstName: 'Jorge'),
      SetupMember(uid: 'demo-101', firstName: 'Mirta'),
    ],
  );

  /// Mirta picked Jorge, who has the green termo.
  static final picked = Welcome(
    rondaId: 'r1',
    newcomerUid: 'demo-105',
    newcomerName: 'Nico',
    week: '2026-W45',
    date: thursday,
    hour: '16:00',
    placeName: 'frente al quiosco',
    placeLandmark: 'al lado de la parada',
    waiter: jorge,
    picked: true,
    sign: 'tiene el termo verde',
    setBy: mirta,
    choices: open.choices,
  );
}
