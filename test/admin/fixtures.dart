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
    List<UnseatedPerson> unseated = const [],
  }) => Proposal(
    id: 'p1',
    status: status,
    rondas: rondas,
    unseatedCount: 2,
    createdAt: DateTime.utc(2026, 10, 27, 15),
    rejectedReason: rejectedReason,
    unseated: unseated,
  );
}

/// Invented sign-ups and numbers for the pilot admin's tests.
abstract final class PilotFixtures {
  static const eva = Candidate(
    uid: 'eva',
    firstName: 'Eva',
    ageBandId: '30-39',
    barrioId: 'el-pinar-norte',
    slotIds: ['sat-afternoon'],
    warnings: [],
    blocks: 9,
  );

  static const gabi = Candidate(
    uid: 'gabi',
    firstName: 'Gabi',
    ageBandId: '30-39',
    barrioId: 'lagomar-sur',
    slotIds: ['tue-evening', 'sat-afternoon'],
    warnings: [CandidateWarning.slot, CandidateWarning.barrio],
    blocks: 84,
    currentRondaId: 'r2',
    currentRondaLine: 'Martes a la noche · truco',
  );

  static RondaCandidates candidates({
    int taken = 3,
    List<Candidate> people = const [eva, gabi],
  }) => RondaCandidates(
    rondaId: 'r1',
    line: 'Sábado a la tarde · mate en la rambla',
    members: const ['Ana', 'Beto', 'Cora'],
    taken: taken,
    cap: 6,
    people: people,
  );

  static final numbers = PilotNumbers(
    profiles: const CountOf(9, 10),
    seated: const CountOf(6, 9),
    cameBack: const CountOf(1, 3),
    rondas: [
      PilotRonda(
        rondaId: 'r1',
        line: 'Sábado a la tarde · mate en la rambla',
        members: const CountOf(5, 6),
        cameBack: const CountOf(1, 3),
        seguimos: const PilotSeguimos(yes: CountOf(3, 4), no: 1, unanswered: 0),
        weeks: [
          PilotWeek(
            week: '2026-W44',
            date: DateTime(2026, 10, 31),
            yes: const CountOf(3, 5),
            no: 1,
            unanswered: 1,
            came: const CountOf(3, 4),
          ),
          const PilotWeek(
            week: '2026-W45',
            yes: CountOf(0, 5),
            no: 0,
            unanswered: 5,
          ),
        ],
      ),
      const PilotRonda(
        rondaId: 'r2',
        line: 'Martes a la noche · truco',
        members: CountOf(4, 6),
        weeks: [],
      ),
    ],
  );
}
