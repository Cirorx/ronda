import 'package:ronda_repository/ronda_repository.dart';

/// An invented roll: Thursday 5/11 at 16:00, three neighbours, Jorge marked.
abstract final class AttendanceFixtures {
  static AttendanceRoll roll({
    Map<String, bool> marks = const {'demo-102': true},
  }) => AttendanceRoll(
    week: '2026-W45',
    date: DateTime(2026, 11, 5),
    line: 'Jueves 16:00 · mate en la rambla · frente al quiosco',
    people: const [
      SetupMember(uid: 'demo-103', firstName: 'Ana'),
      SetupMember(uid: 'demo-102', firstName: 'Jorge'),
      SetupMember(uid: 'demo-101', firstName: 'Mirta'),
    ],
    marks: marks,
  );
}
