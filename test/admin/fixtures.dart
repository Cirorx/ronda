import 'package:ronda_repository/ronda_repository.dart';

/// Invented proposals for the admin tests: no real people.
abstract final class AdminFixtures {
  static const ronda = ProposedRonda(
    seatId: 'lagomar-sur_mate_sat-afternoon',
    barrioId: 'lagomar-sur',
    pretextId: 'mate',
    slotId: 'sat-afternoon',
    members: [
      ProposedMember(
        uid: 'demo-001',
        firstName: 'Marta',
        ageBandId: '60-69',
        distanceBlocks: 0,
        plusOneInGroup: true,
      ),
      ProposedMember(
        uid: 'demo-002',
        firstName: 'Raúl',
        ageBandId: '70-79',
        distanceBlocks: 1,
      ),
      ProposedMember(
        uid: 'demo-003',
        firstName: 'Sofía',
        ageBandId: '18-29',
        distanceBlocks: 4.4,
      ),
    ],
  );

  static Proposal proposal({
    ProposalStatus status = ProposalStatus.pending,
    List<ProposedRonda> rondas = const [ronda],
    String? rejectedReason =
        'Alternativa B rechazada: hace caminar 18 cuadras más.',
  }) => Proposal(
    id: 'p1',
    status: status,
    rondas: rondas,
    unseatedCount: 2,
    createdAt: DateTime.utc(2026, 10, 27, 15),
    rejectedReason: rejectedReason,
  );
}
