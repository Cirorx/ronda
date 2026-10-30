import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockProposalsApi extends Mock implements ProposalsApi;

class _MockRondasApi extends Mock implements RondasApi;

void main() {
  group('RondaRepository.cerca', () {
    late RondasApi rondasApi;
    late RondaRepository subject;

    setUp(() {
      rondasApi = _MockRondasApi();
      subject = RondaRepository(
        proposalsApi: _MockProposalsApi(),
        rondasApi: rondasApi,
      );
    });

    test(
      'times out after ${RondaRepository.defaultCercaTimeout} by default',
      () {
        expect(RondaRepository.defaultCercaTimeout, const Duration(seconds: 8));
      },
    );

    test("reads the barrio's demand by slot and by pretext", () async {
      when(() => rondasApi.readCerca('el-pinar-sur')).thenAnswer(
        (_) async => const CercaDocument(
          barrio: 'el-pinar-sur',
          slotWaiting: [
            CercaSlotWaiting(pretext: 'mate', slot: 'sat-afternoon', count: 4),
          ],
          pretextWaiting: [CercaPretextWaiting(pretext: 'mate', count: 6)],
        ),
      );

      expect(
        await subject.cerca('el-pinar-sur'),
        equals(
          const Cerca(
            barrioId: 'el-pinar-sur',
            bySlot: [
              CercaWaiting(
                pretextId: 'mate',
                slotId: 'sat-afternoon',
                count: 4,
              ),
            ],
            byPretext: [CercaWaiting(pretextId: 'mate', count: 6)],
          ),
        ),
      );
    });

    test('is empty while the barrio has no counts yet', () async {
      when(() => rondasApi.readCerca(any())).thenAnswer((_) async => null);

      expect(
        await subject.cerca('el-pinar-sur'),
        equals(const Cerca(barrioId: 'el-pinar-sur')),
      );
    });

    test('throws a $CercaFailure when the read fails', () {
      when(() => rondasApi.readCerca(any())).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

      expect(subject.cerca('el-pinar-sur'), throwsA(isA<CercaFailure>()));
    });

    test('throws a $CercaFailure when the read takes too long', () {
      subject = RondaRepository(
        proposalsApi: _MockProposalsApi(),
        rondasApi: rondasApi,
        cercaTimeout: Duration.zero,
      );
      when(() => rondasApi.readCerca(any()))
          .thenAnswer((_) => Completer<CercaDocument?>().future);

      expect(subject.cerca('el-pinar-sur'), throwsA(isA<CercaFailure>()));
    });
  });
}
