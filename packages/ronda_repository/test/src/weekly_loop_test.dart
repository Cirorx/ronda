import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockProposalsApi extends Mock implements ProposalsApi;

class _MockRondasApi extends Mock implements RondasApi;

const _ronda = RondaDocument(
  id: 'r1',
  pretext: 'mate',
  barrio: 'el-pinar-sur',
  slotDay: 'thu',
  slotBand: 'afternoon',
  anfitrionUid: 'demo-102',
  anfitrionName: 'Jorge',
  colaUid: 'demo-103',
  colaName: 'Ana',
  hostsMonth: '2026-11',
  turns: [
    HostTurnDocument(
      month: '2026-11',
      anfitrionUid: 'demo-102',
      anfitrionName: 'Jorge',
      colaUid: 'demo-103',
      colaName: 'Ana',
    ),
    HostTurnDocument(
      month: 'later',
      anfitrionUid: 'x',
      anfitrionName: 'X',
      colaUid: 'y',
      colaName: 'Y',
    ),
  ],
  openerWeek: '2026-W45',
  openerUid: 'demo-104',
  openerName: 'Facu',
);

const _view = WeekViewDocument(
  week: '2026-W45',
  date: '2026-11-05',
  going: [],
  noCount: 0,
  unansweredCount: 4,
);

const _home = DespuesDocument(
  week: '2026-W45',
  kind: 'home',
  status: 'set',
  setByUid: 'demo-102',
  setByName: 'Jorge',
  what: 'bizcochos',
  homeOfUid: 'demo-101',
  homeName: 'Mirta',
  address: 'Av. Central 1234',
);

const _ask = HandoffAskDocument(
  week: '2026-W45',
  date: '2026-11-05',
  status: 'open',
  fromName: 'Jorge',
  reason: 'no',
  hour: '16:00',
);

void main() {
  group('RondaRepository weekly loop', () {
    late RondasApi rondasApi;
    late RondaRepository subject;
    late StreamController<DespuesDocument?> despues;
    late StreamController<HandoffAskDocument?> asks;

    setUp(() {
      rondasApi = _MockRondasApi();
      subject = RondaRepository(
        proposalsApi: _MockProposalsApi(),
        rondasApi: rondasApi,
      );
      despues = StreamController<DespuesDocument?>();
      asks = StreamController<HandoffAskDocument?>();
      when(() => rondasApi.watchRondaIds('demo-104'))
          .thenAnswer((_) => Stream.value(['r1']));
      when(() => rondasApi.watchRonda('r1'))
          .thenAnswer((_) => Stream.value(_ronda));
      when(() => rondasApi.watchMember('r1', 'demo-104')).thenAnswer(
        (_) => Stream.value(const MemberDocument(brings: [], state: 'active')),
      );
      when(() => rondasApi.watchWeekView('r1'))
          .thenAnswer((_) => Stream.value(_view));
      when(() => rondasApi.watchAnswer('r1', 'demo-104'))
          .thenAnswer((_) => Stream.value(null));
      when(() => rondasApi.watchDespues('r1', '2026-W45'))
          .thenAnswer((_) => despues.stream);
      when(() => rondasApi.watchHandoffAsk('r1', 'demo-104'))
          .thenAnswer((_) => asks.stream);
    });

    tearDown(() {
      unawaited(despues.close());
      unawaited(asks.close());
    });

    group('watchThisWeek', () {
      test('carries the turns, the opener, the después and the ask', () async {
        despues.add(_home);
        asks.add(_ask);

        final week = (await subject.watchThisWeek('demo-104').first)!;

        expect(week.turns, [
          HostTurn(
            month: DateTime(2026, 11),
            anfitrion: const Host(uid: 'demo-102', firstName: 'Jorge'),
            cola: const Host(uid: 'demo-103', firstName: 'Ana'),
          ),
        ]);
        expect(week.opener, const Host(uid: 'demo-104', firstName: 'Facu'));
        expect(
          week.despues,
          const Despues(
            kind: DespuesKind.home,
            status: DespuesStatus.set,
            setBy: Host(uid: 'demo-102', firstName: 'Jorge'),
            what: 'bizcochos',
            homeOf: Host(uid: 'demo-101', firstName: 'Mirta'),
            address: 'Av. Central 1234',
          ),
        );
        expect(
          week.handoffAsk,
          HandoffAsk(
            week: '2026-W45',
            date: DateTime(2026, 11, 5),
            hour: '16:00',
            fromName: 'Jorge',
            reason: HandoffReason.no,
          ),
        );
      });

      test('leaves out what belongs to another week or is closed', () async {
        when(() => rondasApi.watchRonda('r1')).thenAnswer(
          (_) => Stream.value(
            const RondaDocument(
              id: 'r1',
              pretext: 'mate',
              barrio: 'el-pinar-sur',
              slotDay: 'thu',
              slotBand: 'afternoon',
              openerWeek: '2026-W44',
              openerUid: 'demo-104',
            ),
          ),
        );
        despues.add(
          const DespuesDocument(
            week: '2026-W44',
            kind: 'none',
            status: 'set',
            setByUid: 'demo-102',
            setByName: 'Jorge',
          ),
        );
        asks.add(
          const HandoffAskDocument(
            week: '2026-W45',
            date: 'x',
            status: 'closed',
            fromName: '',
            reason: '',
          ),
        );

        final week = (await subject.watchThisWeek('demo-104').first)!;

        expect(week.opener, isNull);
        expect(week.despues, isNull);
        expect(week.handoffAsk, isNull);
      });

      test("a después of a kind or status it doesn't know reads as none", () {
        despues.add(
          const DespuesDocument(
            week: '2026-W45',
            kind: 'party',
            status: 'set',
            setByUid: 'demo-102',
            setByName: 'Jorge',
          ),
        );
        asks.add(
          const HandoffAskDocument(
            week: '2026-W45',
            date: 'x',
            status: 'open',
            fromName: '',
            reason: '',
          ),
        );

        expect(
          subject.watchThisWeek('demo-104'),
          emits(
            isA<ThisWeek>()
                .having((w) => w.despues, 'despues', isNull)
                .having((w) => w.handoffAsk?.date, 'date', DateTime(0))
                .having((w) => w.handoffAsk?.fromName, 'fromName', isNull),
          ),
        );
      });

      test('with no view yet there is no después to read', () async {
        when(() => rondasApi.watchWeekView('r1'))
            .thenAnswer((_) => Stream.value(null));
        asks.add(null);

        final week = (await subject.watchThisWeek('demo-104').first)!;

        expect(week.despues, isNull);
        verifyNever(() => rondasApi.watchDespues(any(), any()));
      });
    });

    group('the después', () {
      test('setDespues sends the kind by name', () async {
        when(
          () => rondasApi.setDespues(
            rondaId: any(named: 'rondaId'),
            week: any(named: 'week'),
            kind: any(named: 'kind'),
            what: any(named: 'what'),
            where: any(named: 'where'),
            homeOfUid: any(named: 'homeOfUid'),
            address: any(named: 'address'),
          ),
        ).thenAnswer((_) async {});

        await subject.setDespues(
          rondaId: 'r1',
          week: '2026-W45',
          kind: DespuesKind.home,
          what: 'bizcochos',
          homeOfUid: 'demo-101',
          address: 'Av. Central 1234',
        );

        verify(
          () => rondasApi.setDespues(
            rondaId: 'r1',
            week: '2026-W45',
            kind: 'home',
            what: 'bizcochos',
            homeOfUid: 'demo-101',
            address: 'Av. Central 1234',
          ),
        ).called(1);
      });

      test('setDespues says when the words were refused', () {
        when(
          () => rondasApi.setDespues(
            rondaId: any(named: 'rondaId'),
            week: any(named: 'week'),
            kind: any(named: 'kind'),
            what: any(named: 'what'),
            where: any(named: 'where'),
            homeOfUid: any(named: 'homeOfUid'),
            address: any(named: 'address'),
          ),
        ).thenThrow(
          FirebaseException(plugin: 'x', code: 'failed-precondition'),
        );

        expect(
          subject.setDespues(rondaId: 'r1', week: 'w', kind: DespuesKind.none),
          throwsA(
            isA<HostsFailure>().having(
              (f) => f.reason,
              'reason',
              HostsFailureReason.notPublic,
            ),
          ),
        );
      });

      test('answerDespues passes the answer and says when it passed', () async {
        when(() => rondasApi.answerDespues(rondaId: 'r1', week: 'w', yes: true))
            .thenAnswer((_) async {});
        when(
          () => rondasApi.answerDespues(rondaId: 'r1', week: 'w', yes: false),
        ).thenThrow(
          FirebaseException(plugin: 'x', code: 'failed-precondition'),
        );

        await subject.answerDespues(rondaId: 'r1', week: 'w', yes: true);

        await expectLater(
          subject.answerDespues(rondaId: 'r1', week: 'w', yes: false),
          throwsA(
            isA<HostsFailure>().having(
              (f) => f.reason,
              'reason',
              HostsFailureReason.passed,
            ),
          ),
        );
      });
    });

    group('"¿Abrís vos?"', () {
      test('answerHandoff passes the answer, and someone else opening '
          'reads as passed', () async {
        when(
          () => rondasApi.answerHandoff(rondaId: 'r1', week: 'w', yes: false),
        ).thenAnswer((_) async {});
        when(() => rondasApi.answerHandoff(rondaId: 'r1', week: 'w', yes: true))
            .thenThrow(
              FirebaseException(plugin: 'x', code: 'failed-precondition'),
            );

        await subject.answerHandoff(rondaId: 'r1', week: 'w', yes: false);

        await expectLater(
          subject.answerHandoff(rondaId: 'r1', week: 'w', yes: true),
          throwsA(
            isA<HostsFailure>().having(
              (f) => f.reason,
              'reason',
              HostsFailureReason.passed,
            ),
          ),
        );
      });
    });

    group('the buddy', () {
      test('watchBuddyAsk emits the open card and null otherwise', () {
        final cards = StreamController<BuddyAskDocument?>();
        addTearDown(() => unawaited(cards.close()));
        when(() => rondasApi.watchBuddyAsk('r1', 'demo-104'))
            .thenAnswer((_) => cards.stream);

        expect(
          subject.watchBuddyAsk('demo-104'),
          emitsInOrder([
            const BuddyAsk(
              rondaId: 'r1',
              misses: [BuddyMiss(firstName: 'Jorge', dayId: 'thu')],
            ),
            isNull,
            isNull,
            isNull,
          ]),
        );
        cards
          ..add(
            const BuddyAskDocument(
              status: 'open',
              asks: [BuddyMissDocument(firstName: 'Jorge', day: 'thu')],
            ),
          )
          ..add(const BuddyAskDocument(status: 'closed', asks: []))
          ..add(const BuddyAskDocument(status: 'open', asks: []))
          ..add(null);
      });

      test('watchBuddyAsk is null while the member is in no ronda', () {
        when(() => rondasApi.watchRondaIds('demo-104'))
            .thenAnswer((_) => Stream.value([]));

        expect(subject.watchBuddyAsk('demo-104'), emits(isNull));
      });

      test('watchBuddyAsk errors with a $HostsFailure', () {
        when(() => rondasApi.watchBuddyAsk('r1', 'demo-104'))
            .thenAnswer((_) => Stream.error(Exception('down')));

        expect(
          subject.watchBuddyAsk('demo-104'),
          emitsError(isA<HostsFailure>()),
        );
      });

      test('closeBuddyAsk closes it', () async {
        when(() => rondasApi.closeBuddyAsk('r1', 'demo-104'))
            .thenAnswer((_) async {});

        await subject.closeBuddyAsk(rondaId: 'r1', uid: 'demo-104');

        verify(() => rondasApi.closeBuddyAsk('r1', 'demo-104')).called(1);
      });

      test('buddyOptions reads the choices and who was chosen', () async {
        when(() => rondasApi.buddyOptions('r1')).thenAnswer(
          (_) async => const BuddyOptionsDocument(
            due: true,
            chosen: true,
            buddyUid: 'demo-101',
            buddyName: 'Mirta',
            choices: [SetupMemberDocument(uid: 'demo-101', firstName: 'Mirta')],
          ),
        );

        expect(
          await subject.buddyOptions('r1'),
          const BuddyOptions(
            due: true,
            chosen: true,
            buddy: SetupMember(uid: 'demo-101', firstName: 'Mirta'),
            choices: [SetupMember(uid: 'demo-101', firstName: 'Mirta')],
          ),
        );
      });

      test('buddyOptions reads nobody, and a buddy with no name', () async {
        when(() => rondasApi.buddyOptions('r1')).thenAnswer(
          (_) async =>
              const BuddyOptionsDocument(due: false, chosen: true, choices: []),
        );
        when(() => rondasApi.buddyOptions('r2')).thenAnswer(
          (_) async => const BuddyOptionsDocument(
            due: true,
            chosen: true,
            buddyUid: 'demo-101',
            choices: [],
          ),
        );

        expect((await subject.buddyOptions('r1')).buddy, isNull);
        expect(
          (await subject.buddyOptions('r2')).buddy,
          const SetupMember(uid: 'demo-101', firstName: ''),
        );
      });

      test(
        'setBuddy saves someone or nobody, and fails as a $HostsFailure',
        () async {
          when(() => rondasApi.setBuddy(rondaId: 'r1', buddyUid: 'demo-101'))
              .thenAnswer((_) async {});
          when(() => rondasApi.setBuddy(rondaId: 'r1')).thenThrow(
            FirebaseException(plugin: 'x', code: 'permission-denied'),
          );

          await subject.setBuddy(rondaId: 'r1', buddyUid: 'demo-101');

          await expectLater(
            subject.setBuddy(rondaId: 'r1'),
            throwsA(
              isA<HostsFailure>().having(
                (f) => f.reason,
                'reason',
                HostsFailureReason.forbidden,
              ),
            ),
          );
        },
      );
    });

    group('rondaSetups', () {
      test('carries how the upcoming "¿Abrís vos?" is going', () async {
        RondaSetupDocument row(HandoffSummaryDocument? handoff) =>
            RondaSetupDocument(
              rondaId: 'r1',
              line: 'Jueves a la tarde · mate',
              pretext: 'mate',
              barrio: 'el-pinar-sur',
              slotDay: 'thu',
              slotBand: 'afternoon',
              members: const [],
              handoff: handoff,
            );
        when(() => rondasApi.rondaSetups()).thenAnswer(
          (_) async => [
            row(
              const HandoffSummaryDocument(
                week: '2026-W45',
                date: '2026-11-05',
                step: 'nobody',
                fromName: 'Jorge',
              ),
            ),
            row(
              const HandoffSummaryDocument(
                week: '2026-W45',
                date: '2026-11-05',
                step: 'later',
                fromName: 'Jorge',
              ),
            ),
            row(
              const HandoffSummaryDocument(
                week: '2026-W45',
                date: 'x',
                step: 'taken',
                fromName: 'Jorge',
              ),
            ),
          ],
        );

        final rows = await subject.rondaSetups();

        expect(
          rows.first.handoff,
          HandoffSummary(
            date: DateTime(2026, 11, 5),
            step: HandoffStep.nobody,
            fromName: 'Jorge',
          ),
        );
        expect(rows[1].handoff, isNull);
        expect(rows[2].handoff, isNull);
      });
    });
  });
}
