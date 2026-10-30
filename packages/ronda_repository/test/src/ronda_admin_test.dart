import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockProposalsApi extends Mock implements ProposalsApi;

class _MockRondasApi extends Mock implements RondasApi;

void main() {
  group('$RondaRepository for the pilot admin', () {
    late ProposalsApi proposalsApi;
    late RondasApi rondasApi;
    late RondaRepository subject;

    setUp(() {
      proposalsApi = _MockProposalsApi();
      rondasApi = _MockRondasApi();
      subject = RondaRepository(
        proposalsApi: proposalsApi,
        rondasApi: rondasApi,
      );
    });

    Matcher failsWith(ProposalsFailureReason reason) => throwsA(
      isA<ProposalsFailure>().having((f) => f.reason, 'reason', reason),
    );

    group('rondaCandidates', () {
      test('reads who could join, with what does not match', () async {
        when(() => proposalsApi.rondaCandidates('r1')).thenAnswer(
          (_) async => const RondaCandidatesDocument(
            rondaId: 'r1',
            line: 'Sábado a la tarde · mate en la rambla',
            members: ['Ana'],
            taken: 6,
            cap: 6,
            people: [
              CandidateDocument(
                uid: 'gabi',
                firstName: 'Gabi',
                ageBand: '30-39',
                barrio: 'el-pinar-norte',
                slots: ['tue-evening'],
                pretexts: ['truco'],
                warnings: ['slot', 'unknown', 'seat'],
                blocks: 9,
                rondaId: 'r2',
                rondaLine: 'Martes a la noche · truco',
              ),
            ],
          ),
        );

        final candidates = await subject.rondaCandidates('r1');

        expect(
          candidates,
          const RondaCandidates(
            rondaId: 'r1',
            line: 'Sábado a la tarde · mate en la rambla',
            members: ['Ana'],
            taken: 6,
            cap: 6,
            people: [
              Candidate(
                uid: 'gabi',
                firstName: 'Gabi',
                ageBandId: '30-39',
                barrioId: 'el-pinar-norte',
                slotIds: ['tue-evening'],
                warnings: [CandidateWarning.slot, CandidateWarning.seat],
                blocks: 9,
                currentRondaId: 'r2',
                currentRondaLine: 'Martes a la noche · truco',
              ),
            ],
          ),
        );
        expect(candidates.full, isTrue);
      });

      test('throws forbidden without the admin claim', () {
        when(() => proposalsApi.rondaCandidates('r1')).thenThrow(
          FirebaseFunctionsException(code: 'permission-denied', message: ''),
        );

        expect(
          () => subject.rondaCandidates('r1'),
          failsWith(ProposalsFailureReason.forbidden),
        );
      });
    });

    group('addToRonda', () {
      test('adds them and says what does not match', () async {
        when(
          () => proposalsApi.addToRonda(rondaId: 'r1', uid: 'gabi', move: true),
        ).thenAnswer(
          (_) async => const AddToRondaDocument(
            rondaId: 'r1',
            uid: 'gabi',
            warnings: ['barrio'],
            movedFrom: 'r2',
          ),
        );

        expect(
          await subject.addToRonda(rondaId: 'r1', uid: 'gabi', move: true),
          const AddedToRonda(
            rondaId: 'r1',
            uid: 'gabi',
            warnings: [CandidateWarning.barrio],
            movedFrom: 'r2',
          ),
        );
      });

      final refusals = {
        'resource-exhausted': ProposalsFailureReason.full,
        'already-exists': ProposalsFailureReason.alreadyIn,
        'failed-precondition': ProposalsFailureReason.other,
      };
      for (final MapEntry(key: code, value: reason) in refusals.entries) {
        test('throws $reason for $code', () {
          when(() => proposalsApi.addToRonda(rondaId: 'r1', uid: 'eva'))
              .thenThrow(FirebaseFunctionsException(code: code, message: ''));

          expect(
            () => subject.addToRonda(rondaId: 'r1', uid: 'eva'),
            failsWith(reason),
          );
        });
      }
    });

    group('pilotNumbers', () {
      test('reads every count as x of y', () async {
        when(rondasApi.pilotNumbers).thenAnswer(
          (_) async => const PilotNumbersDocument(
            profiles: 9,
            signUps: 10,
            seated: 6,
            cameBack: CountOfDocument(1, 3),
            rondas: [
              PilotRondaDocument(
                rondaId: 'r1',
                line: 'Sábado a la tarde · mate en la rambla',
                status: 'active',
                members: 5,
                cap: 6,
                cameBack: CountOfDocument(1, 3),
                seguimos: PilotSeguimosDocument(
                  status: 'season',
                  asked: 4,
                  yes: 3,
                  no: 1,
                  unanswered: 0,
                ),
                weeks: [
                  PilotWeekDocument(
                    week: '2026-W44',
                    date: '2026-10-31',
                    members: 5,
                    yes: 3,
                    no: 1,
                    unanswered: 1,
                    came: 3,
                    marked: 4,
                  ),
                  PilotWeekDocument(
                    week: '2026-W45',
                    members: 5,
                    yes: 0,
                    no: 0,
                    unanswered: 5,
                  ),
                ],
              ),
              PilotRondaDocument(
                rondaId: 'r2',
                line: 'Martes a la noche · truco',
                status: 'forming',
                members: 4,
                cap: 6,
                weeks: [],
              ),
            ],
          ),
        );

        expect(
          await subject.pilotNumbers(),
          PilotNumbers(
            profiles: const CountOf(9, 10),
            seated: const CountOf(6, 9),
            cameBack: const CountOf(1, 3),
            rondas: [
              PilotRonda(
                rondaId: 'r1',
                line: 'Sábado a la tarde · mate en la rambla',
                members: const CountOf(5, 6),
                cameBack: const CountOf(1, 3),
                seguimos: const PilotSeguimos(
                  yes: CountOf(3, 4),
                  no: 1,
                  unanswered: 0,
                ),
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
          ),
        );
      });

      test('throws other when the answer has another shape', () {
        when(rondasApi.pilotNumbers).thenThrow(const FormatException('x'));

        expect(subject.pilotNumbers, failsWith(ProposalsFailureReason.other));
      });
    });
  });
}
