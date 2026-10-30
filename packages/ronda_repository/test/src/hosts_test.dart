import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockProposalsApi extends Mock implements ProposalsApi;

class _MockRondasApi extends Mock implements RondasApi;

const _setup = RondaSetupDocument(
  rondaId: 'r1',
  line: 'Jueves 16:00 · mate en la rambla',
  pretext: 'mate',
  barrio: 'el-pinar-sur',
  slotDay: 'thu',
  slotBand: 'afternoon',
  members: [SetupMemberDocument(uid: 'demo-101', firstName: 'Mirta')],
  hour: '16:00',
  placeName: 'frente al quiosco',
  placeLandmark: 'la parada',
  anfitrionUid: 'demo-101',
  colaUid: 'demo-102',
  roll: RollSummaryDocument(
    week: '2026-W45',
    date: '2026-11-05',
    people: 4,
    marked: 1,
  ),
);

const _roll = RollDocument(
  week: '2026-W45',
  date: '2026-11-05',
  line: 'Jueves 16:00 · mate en la rambla',
  people: [SetupMemberDocument(uid: 'demo-102', firstName: 'Jorge')],
  marks: {'demo-102': true},
);

FirebaseException _error(String code) =>
    FirebaseException(plugin: 'functions', code: code);

void main() {
  group('RondaRepository hosts and attendance', () {
    late RondasApi rondasApi;
    late RondaRepository subject;

    setUp(() {
      rondasApi = _MockRondasApi();
      when(() => rondasApi.watchHandoffAsk(any(), any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => rondasApi.watchDespues(any(), any()))
          .thenAnswer((_) => Stream.value(null));
      subject = RondaRepository(
        proposalsApi: _MockProposalsApi(),
        rondasApi: rondasApi,
      );
    });

    group('watchThisWeek', () {
      test('carries the place, hour and hosts the admin set', () async {
        when(() => rondasApi.watchRondaIds('demo-001'))
            .thenAnswer((_) => Stream.value(['r1']));
        when(() => rondasApi.watchRonda('r1')).thenAnswer(
          (_) => Stream.value(
            const RondaDocument(
              id: 'r1',
              pretext: 'mate',
              barrio: 'el-pinar-sur',
              slotDay: 'thu',
              slotBand: 'afternoon',
              placeName: 'frente al quiosco',
              placeLandmark: 'la parada',
              slotHour: '16:00',
              anfitrionUid: 'demo-101',
              anfitrionName: 'Mirta',
              colaUid: 'demo-102',
            ),
          ),
        );
        when(() => rondasApi.watchMember('r1', 'demo-001')).thenAnswer(
          (_) =>
              Stream.value(const MemberDocument(brings: [], state: 'active')),
        );
        when(() => rondasApi.watchWeekView('r1'))
            .thenAnswer((_) => Stream.value(null));
        when(() => rondasApi.watchAnswer('r1', 'demo-001'))
            .thenAnswer((_) => Stream.value(null));

        final week = (await subject.watchThisWeek('demo-001').first)!;

        expect(week.hour, '16:00');
        expect(week.placeLandmark, 'la parada');
        expect(week.anfitrion, const Host(uid: 'demo-101', firstName: 'Mirta'));
        expect(week.cola, const Host(uid: 'demo-102', firstName: ''));
      });
    });

    group('rondaSetups', () {
      test('turns each row into a $RondaSetup', () async {
        when(() => rondasApi.rondaSetups()).thenAnswer(
          (_) async => [
            _setup,
            const RondaSetupDocument(
              rondaId: 'r2',
              line: 'x',
              pretext: 'truco',
              barrio: 'lagomar-sur',
              slotDay: 'tue',
              slotBand: 'evening',
              members: [],
              roll: RollSummaryDocument(
                week: '2026-W45',
                date: 'not a date',
                people: 0,
                marked: 0,
              ),
            ),
          ],
        );

        final rows = await subject.rondaSetups();

        expect(
          rows.first,
          RondaSetup(
            rondaId: 'r1',
            pretextId: 'mate',
            barrioId: 'el-pinar-sur',
            slotDayId: 'thu',
            slotBandId: 'afternoon',
            members: const [SetupMember(uid: 'demo-101', firstName: 'Mirta')],
            hour: '16:00',
            placeName: 'frente al quiosco',
            placeLandmark: 'la parada',
            anfitrionUid: 'demo-101',
            colaUid: 'demo-102',
            roll: RollSummary(
              week: '2026-W45',
              date: DateTime(2026, 11, 5),
              people: 4,
              marked: 1,
            ),
          ),
        );
        expect(rows.last.roll, isNull);
      });

      test('throws a forbidden $HostsFailure for anyone but the admin', () {
        when(() => rondasApi.rondaSetups())
            .thenThrow(_error('permission-denied'));

        expect(
          subject.rondaSetups(),
          throwsA(
            isA<HostsFailure>().having(
              (f) => f.reason,
              'reason',
              HostsFailureReason.forbidden,
            ),
          ),
        );
      });
    });

    group('setRondaSetup', () {
      test('sends all three', () async {
        when(
          () => rondasApi.setRondaSetup(
            rondaId: any(named: 'rondaId'),
            placeName: any(named: 'placeName'),
            placeLandmark: any(named: 'placeLandmark'),
            hour: any(named: 'hour'),
            anfitrionUid: any(named: 'anfitrionUid'),
            colaUid: any(named: 'colaUid'),
          ),
        ).thenAnswer((_) async {});

        await subject.setRondaSetup(
          rondaId: 'r1',
          placeName: 'la plaza',
          hour: '16:00',
          anfitrionUid: 'demo-101',
        );

        verify(
          () => rondasApi.setRondaSetup(
            rondaId: 'r1',
            placeName: 'la plaza',
            hour: '16:00',
            anfitrionUid: 'demo-101',
          ),
        ).called(1);
      });

      test('a place that is not public is notPublic', () {
        when(
          () => rondasApi.setRondaSetup(
            rondaId: any(named: 'rondaId'),
            placeName: any(named: 'placeName'),
          ),
        ).thenThrow(_error('failed-precondition'));

        expect(
          subject.setRondaSetup(rondaId: 'r1', placeName: 'en lo de Mirta'),
          throwsA(
            isA<HostsFailure>().having(
              (f) => f.reason,
              'reason',
              HostsFailureReason.notPublic,
            ),
          ),
        );
      });
    });

    group('watchRoll', () {
      test('emits the roll', () {
        when(() => rondasApi.watchRoll('r1', '2026-W45'))
            .thenAnswer((_) => Stream.value(_roll));

        expect(
          subject.watchRoll('r1', '2026-W45'),
          emits(
            AttendanceRoll(
              week: '2026-W45',
              date: DateTime(2026, 11, 5),
              line: 'Jueves 16:00 · mate en la rambla',
              people: const [SetupMember(uid: 'demo-102', firstName: 'Jorge')],
              marks: const {'demo-102': true},
            ),
          ),
        );
      });

      test('emits null while there is none', () {
        when(() => rondasApi.watchRoll('r1', '2026-W45'))
            .thenAnswer((_) => Stream.value(null));

        expect(subject.watchRoll('r1', '2026-W45'), emits(isNull));
      });

      test('reads a date it cannot parse as year zero', () async {
        when(() => rondasApi.watchRoll('r1', '2026-W45')).thenAnswer(
          (_) => Stream.value(
            const RollDocument(
              week: '2026-W45',
              date: 'x',
              line: '',
              people: [],
              marks: {},
            ),
          ),
        );

        final roll = await subject.watchRoll('r1', '2026-W45').first;

        expect(roll!.date, DateTime(0));
      });

      test('errors with a $HostsFailure', () {
        when(() => rondasApi.watchRoll('r1', '2026-W45'))
            .thenAnswer((_) => Stream.error(_error('permission-denied')));

        expect(
          subject.watchRoll('r1', '2026-W45'),
          emitsError(
            isA<HostsFailure>().having(
              (f) => f.reason,
              'reason',
              HostsFailureReason.forbidden,
            ),
          ),
        );
      });
    });

    group('recordAttendance', () {
      Future<void> tap() => subject.recordAttendance(
        rondaId: 'r1',
        week: '2026-W45',
        uid: 'demo-102',
        came: true,
      );

      test('records one tap', () async {
        when(
          () => rondasApi.recordAttendance(
            rondaId: any(named: 'rondaId'),
            week: any(named: 'week'),
            uid: any(named: 'uid'),
            came: any(named: 'came'),
          ),
        ).thenAnswer((_) async {});

        await tap();

        verify(
          () => rondasApi.recordAttendance(
            rondaId: 'r1',
            week: '2026-W45',
            uid: 'demo-102',
            came: true,
          ),
        ).called(1);
      });

      test('a meeting too long ago is passed; anything else other', () async {
        when(
          () => rondasApi.recordAttendance(
            rondaId: any(named: 'rondaId'),
            week: any(named: 'week'),
            uid: any(named: 'uid'),
            came: any(named: 'came'),
          ),
        ).thenThrow(_error('failed-precondition'));

        await expectLater(
          tap(),
          throwsA(
            isA<HostsFailure>().having(
              (f) => f.reason,
              'reason',
              HostsFailureReason.passed,
            ),
          ),
        );

        when(
          () => rondasApi.recordAttendance(
            rondaId: any(named: 'rondaId'),
            week: any(named: 'week'),
            uid: any(named: 'uid'),
            came: any(named: 'came'),
          ),
        ).thenThrow(const FormatException('x'));

        await expectLater(
          tap(),
          throwsA(
            isA<HostsFailure>().having(
              (f) => f.reason,
              'reason',
              HostsFailureReason.other,
            ),
          ),
        );
      });
    });
  });
}
