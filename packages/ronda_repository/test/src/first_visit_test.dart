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
  placeName: 'frente al quiosco',
  placeLandmark: 'al lado de la parada',
  slotHour: '16:00',
  anfitrionUid: 'demo-101',
  anfitrionName: 'Mirta',
  colaUid: 'demo-102',
  colaName: 'Jorge',
);

const _open = WelcomeDocument(
  newcomerUid: 'demo-105',
  newcomerName: 'Nico',
  week: '2026-W45',
  date: '2026-11-05',
  status: 'open',
  hour: '16:00',
  choices: [
    SetupMemberDocument(uid: 'demo-101', firstName: 'Mirta'),
    SetupMemberDocument(uid: 'demo-102', firstName: 'Jorge'),
  ],
  declinedName: 'Ana',
);

const _set = WelcomeDocument(
  newcomerUid: 'demo-105',
  newcomerName: 'Nico',
  week: '2026-W45',
  date: '2026-11-05',
  status: 'set',
  choices: [],
  waiterUid: 'demo-103',
  waiterName: 'Ana',
  sign: 'tiene el termo verde',
  setByUid: 'demo-101',
  setByName: 'Mirta',
  declinedName: 'Facu',
);

const _mirta = Host(uid: 'demo-101', firstName: 'Mirta');
const _ana = Host(uid: 'demo-103', firstName: 'Ana');

FirebaseException _error(String code) =>
    FirebaseException(plugin: 'functions', code: code);

void main() {
  group('RondaRepository first visit', () {
    late RondasApi rondasApi;
    late RondaRepository subject;

    setUp(() {
      rondasApi = _MockRondasApi();
      subject = RondaRepository(
        proposalsApi: _MockProposalsApi(),
        rondasApi: rondasApi,
      );
      when(() => rondasApi.watchRondaIds(any()))
          .thenAnswer((_) => Stream.value(['r1']));
      when(() => rondasApi.watchRonda('r1'))
          .thenAnswer((_) => Stream.value(_ronda));
      when(() => rondasApi.watchWelcome('r1', any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => rondasApi.watchWelcomes('r1'))
          .thenAnswer((_) => Stream.value(const [_open]));
      when(() => rondasApi.watchWelcomesFor('r1', any()))
          .thenAnswer((_) => Stream.value(const []));
    });

    group('watchFirstVisit', () {
      test('is null while the member is in no ronda', () async {
        when(() => rondasApi.watchRondaIds('demo-105'))
            .thenAnswer((_) => Stream.value(const []));

        expect(await subject.watchFirstVisit('demo-105').first, isNull);
      });

      test('is null while the ronda is not there', () async {
        when(() => rondasApi.watchRonda('r1'))
            .thenAnswer((_) => Stream.value(null));

        expect(await subject.watchFirstVisit('demo-105').first, isNull);
      });

      test('gives the newcomer the anfitrión while nobody picked, the place '
          'and the hour', () async {
        when(() => rondasApi.watchWelcome('r1', 'demo-105'))
            .thenAnswer((_) => Stream.value(_open));

        final visit = (await subject.watchFirstVisit('demo-105').first)!;

        expect(
          visit.mine,
          Welcome(
            rondaId: 'r1',
            newcomerUid: 'demo-105',
            newcomerName: 'Nico',
            week: '2026-W45',
            date: DateTime(2026, 11, 5),
            choices: const [
              SetupMember(uid: 'demo-101', firstName: 'Mirta'),
              SetupMember(uid: 'demo-102', firstName: 'Jorge'),
            ],
            hour: '16:00',
            placeName: 'frente al quiosco',
            placeLandmark: 'al lado de la parada',
            waiter: _mirta,
            declinedName: 'Ana',
          ),
        );
        expect(visit.toChoose, isEmpty);
        expect(visit.waitingFor, isEmpty);
        expect(visit.props, [
          'r1',
          visit.mine,
          visit.toChoose,
          visit.waitingFor,
        ]);
        verifyNever(() => rondasApi.watchWelcomes(any()));
      });

      test("gives that week's opener when one took over", () async {
        when(() => rondasApi.watchRonda('r1')).thenAnswer(
          (_) => Stream.value(
            const RondaDocument(
              id: 'r1',
              pretext: 'mate',
              barrio: 'el-pinar-sur',
              slotDay: 'thu',
              slotBand: 'afternoon',
              anfitrionUid: 'demo-101',
              anfitrionName: 'Mirta',
              openerWeek: '2026-W45',
              openerUid: 'demo-104',
              openerName: 'Facu',
            ),
          ),
        );
        when(() => rondasApi.watchWelcome('r1', 'demo-105'))
            .thenAnswer((_) => Stream.value(_open));

        final visit = (await subject.watchFirstVisit('demo-105').first)!;

        expect(
          visit.mine?.waiter,
          const Host(uid: 'demo-104', firstName: 'Facu'),
        );
      });

      test('gives nobody when the only one to wait is the newcomer', () async {
        when(() => rondasApi.watchWelcome('r1', 'demo-101')).thenAnswer(
          (_) => Stream.value(
            const WelcomeDocument(
              newcomerUid: 'demo-101',
              newcomerName: 'Mirta',
              week: '2026-W45',
              date: 'not a date',
              status: 'open',
              choices: [],
            ),
          ),
        );

        final visit = (await subject.watchFirstVisit('demo-101').first)!;

        expect((visit.mine?.waiter, visit.mine?.date), (null, DateTime(0)));
      });

      test('gives the picked waiter, the sign and who picked', () async {
        when(() => rondasApi.watchWelcome('r1', 'demo-105'))
            .thenAnswer((_) => Stream.value(_set));

        final mine = (await subject.watchFirstVisit('demo-105').first)!.mine!;

        expect(
          (mine.waiter, mine.picked, mine.sign),
          (_ana, true, 'tiene el termo verde'),
        );
        expect((mine.setBy, mine.declinedName), (_mirta, null));
      });

      test("lists the ronda's newcomers for its hosts", () async {
        final visit = (await subject.watchFirstVisit('demo-102').first)!;

        expect([for (final w in visit.toChoose) w.newcomerName], ['Nico']);
        expect(visit.toChoose.single.picked, isFalse);
      });

      test('a host who is new does not choose for themself', () async {
        when(() => rondasApi.watchWelcomes('r1')).thenAnswer(
          (_) => Stream.value(const [
            WelcomeDocument(
              newcomerUid: 'demo-101',
              newcomerName: 'Mirta',
              week: '2026-W45',
              date: '2026-11-05',
              status: 'open',
              choices: [],
            ),
          ]),
        );

        final visit = (await subject.watchFirstVisit('demo-101').first)!;

        expect(visit.toChoose, isEmpty);
      });

      test(
        'lists what the member was picked for, while still picked',
        () async {
          when(() => rondasApi.watchWelcomesFor('r1', 'demo-103'))
              .thenAnswer((_) => Stream.value(const [_set, _open]));

          final visit = (await subject.watchFirstVisit('demo-103').first)!;

          expect([for (final w in visit.waitingFor) w.waiter], [_ana]);
        },
      );

      test('errors with a $WelcomeFailure', () {
        when(() => rondasApi.watchWelcome('r1', any()))
            .thenAnswer((_) => Stream.error(_error('permission-denied')));

        expect(
          subject.watchFirstVisit('demo-105'),
          emitsError(
            isA<WelcomeFailure>().having(
              (f) => f.reason,
              'reason',
              WelcomeFailureReason.other,
            ),
          ),
        );
      });
    });

    group('setWelcome', () {
      test('sends the pick', () async {
        when(
          () => rondasApi.setWelcome(
            rondaId: any(named: 'rondaId'),
            newcomerUid: any(named: 'newcomerUid'),
            waiterUid: any(named: 'waiterUid'),
            sign: any(named: 'sign'),
          ),
        ).thenAnswer((_) async {});

        await subject.setWelcome(
          rondaId: 'r1',
          newcomerUid: 'demo-105',
          waiterUid: 'demo-103',
          sign: 'tiene el termo verde',
        );

        verify(
          () => rondasApi.setWelcome(
            rondaId: 'r1',
            newcomerUid: 'demo-105',
            waiterUid: 'demo-103',
            sign: 'tiene el termo verde',
          ),
        ).called(1);
      });

      for (final (error, reason) in <(Exception, WelcomeFailureReason)>[
        (const WelcomeHeldException('emoji'), WelcomeFailureReason.emoji),
        (const WelcomeHeldException('voseo'), WelcomeFailureReason.voseo),
        (const WelcomeHeldException('money'), WelcomeFailureReason.money),
        (
          const WelcomeHeldException('public_place'),
          WelcomeFailureReason.notPublic,
        ),
        (const WelcomeHeldException('else'), WelcomeFailureReason.other),
        (_error('failed-precondition'), WelcomeFailureReason.passed),
        (_error('permission-denied'), WelcomeFailureReason.passed),
        (_error('unavailable'), WelcomeFailureReason.other),
        (const FormatException('x'), WelcomeFailureReason.other),
      ]) {
        test('turns $error into $reason', () {
          when(
            () => rondasApi.setWelcome(
              rondaId: any(named: 'rondaId'),
              newcomerUid: any(named: 'newcomerUid'),
              waiterUid: any(named: 'waiterUid'),
              sign: any(named: 'sign'),
            ),
          ).thenThrow(error);

          expect(
            subject.setWelcome(
              rondaId: 'r1',
              newcomerUid: 'demo-105',
              waiterUid: 'demo-103',
            ),
            throwsA(
              isA<WelcomeFailure>().having((f) => f.reason, 'reason', reason),
            ),
          );
        });
      }
    });

    test('declineWelcome hands the choice back', () async {
      when(
        () => rondasApi.declineWelcome(
          rondaId: any(named: 'rondaId'),
          newcomerUid: any(named: 'newcomerUid'),
        ),
      ).thenAnswer((_) async {});

      await subject.declineWelcome(rondaId: 'r1', newcomerUid: 'demo-105');

      verify(
        () => rondasApi.declineWelcome(rondaId: 'r1', newcomerUid: 'demo-105'),
      ).called(1);
    });
  });
}
