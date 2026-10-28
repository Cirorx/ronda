import 'dart:convert';
import 'dart:io';

import 'package:device_store/device_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:needs_repository/needs_repository.dart';

class _MockDeviceStore extends Mock implements DeviceStore;

void main() {
  group(NeedsRepository, () {
    late DeviceStore deviceStore;
    late NeedsRepository subject;

    setUp(() {
      deviceStore = _MockDeviceStore();
      subject = NeedsRepository(deviceStore: deviceStore);
    });

    group('read', () {
      test('returns ${Needs.none} when nothing is stored', () async {
        when(() => deviceStore.read(any())).thenAnswer((_) async => null);

        expect(await subject.read(), equals(Needs.none));
        verify(() => deviceStore.read(NeedsRepository.storageKey)).called(1);
      });

      test('returns the stored needs', () async {
        when(() => deviceStore.read(any()))
            .thenAnswer((_) async => '{"needs":["climbStairs","noCar"]}');

        expect(
          await subject.read(),
          equals(const Needs({Need.climbStairs, Need.noCar})),
        );
      });

      test('returns ${Needs.none} when the stored value is not JSON', () async {
        when(() => deviceStore.read(any())).thenAnswer((_) async => '{oops');

        expect(await subject.read(), equals(Needs.none));
      });

      test(
        'returns ${Needs.none} when the stored JSON has another shape',
        () async {
          when(() => deviceStore.read(any()))
              .thenAnswer((_) async => '{"needs":42}');

          expect(await subject.read(), equals(Needs.none));
        },
      );

      test('returns ${Needs.none} when the stored JSON is a list', () async {
        when(() => deviceStore.read(any()))
            .thenAnswer((_) async => '["noCar"]');

        expect(await subject.read(), equals(Needs.none));
      });

      test(
        'skips names it does not know and entries that are not text',
        () async {
          when(() => deviceStore.read(any()))
              .thenAnswer((_) async => '{"needs":["noCar","flying",7,null]}');

          expect(await subject.read(), equals(const Needs({Need.noCar})));
        },
      );
    });

    group('save', () {
      test(
        'writes one JSON value under ${NeedsRepository.storageKey}',
        () async {
          when(() => deviceStore.write(any(), any())).thenAnswer((_) async {});

          await subject.save(const Needs({Need.noCar, Need.walkALot}));

          verify(
            () => deviceStore.write(
              NeedsRepository.storageKey,
              '{"needs":["walkALot","noCar"]}',
            ),
          ).called(1);
        },
      );

      test('round-trips through the device store', () async {
        String? stored;
        when(() => deviceStore.write(any(), any()))
            .thenAnswer((invocation) async {
              stored = invocation.positionalArguments[1] as String;
            });
        when(() => deviceStore.read(any())).thenAnswer((_) async => stored);
        const needs = Needs({Need.returnAfterDark, Need.climbStairs});

        await subject.save(needs);

        expect(await subject.read(), equals(needs));
      });

      test('round-trips empty needs', () async {
        String? stored;
        when(() => deviceStore.write(any(), any()))
            .thenAnswer((invocation) async {
              stored = invocation.positionalArguments[1] as String;
            });
        when(() => deviceStore.read(any())).thenAnswer((_) async => stored);

        await subject.save(Needs.none);

        expect(stored, equals('{"needs":[]}'));
        expect(await subject.read(), equals(Needs.none));
      });
    });

    group('clear', () {
      test('deletes ${NeedsRepository.storageKey}', () async {
        when(() => deviceStore.delete(any())).thenAnswer((_) async {});

        await subject.clear();

        verify(() => deviceStore.delete(NeedsRepository.storageKey)).called(1);
      });
    });

    group('eligibleSeatIds', () {
      SeatFacts seat(
        String seatId, {
        WalkDistance walkDistance = WalkDistance.near,
        bool hasStairs = false,
        bool endsAfterDark = false,
        bool needsCar = false,
      }) => SeatFacts(
        seatId: seatId,
        walkDistance: walkDistance,
        hasStairs: hasStairs,
        endsAfterDark: endsAfterDark,
        needsCar: needsCar,
      );

      final seats = [
        seat('near'),
        seat('medium', walkDistance: WalkDistance.medium),
        seat('far', walkDistance: WalkDistance.far),
        seat('stairs', hasStairs: true),
        seat('after-dark', endsAfterDark: true),
        seat('car', needsCar: true),
      ];

      test('keeps every seat, in order, when there are no needs', () {
        expect(
          subject.eligibleSeatIds(Needs.none, seats),
          equals(['near', 'medium', 'far', 'stairs', 'after-dark', 'car']),
        );
      });

      test('drops far seats only when walking a lot is hard', () {
        expect(
          subject.eligibleSeatIds(const Needs({Need.walkALot}), seats),
          equals(['near', 'medium', 'stairs', 'after-dark', 'car']),
        );
      });

      test('drops seats with stairs when climbing stairs is hard', () {
        expect(
          subject.eligibleSeatIds(const Needs({Need.climbStairs}), seats),
          equals(['near', 'medium', 'far', 'after-dark', 'car']),
        );
      });

      test('drops seats that end after dark when coming back at night '
          'is hard', () {
        expect(
          subject.eligibleSeatIds(const Needs({Need.returnAfterDark}), seats),
          equals(['near', 'medium', 'far', 'stairs', 'car']),
        );
      });

      test('drops seats that need a car when the member has none', () {
        expect(
          subject.eligibleSeatIds(const Needs({Need.noCar}), seats),
          equals(['near', 'medium', 'far', 'stairs', 'after-dark']),
        );
      });

      test('drops far seats and seats that end after dark when both walking '
          'a lot and coming back at night are hard', () {
        final week = [
          seat('cerca-de-dia'),
          seat('lejos-de-dia', walkDistance: WalkDistance.far),
          seat('cerca-de-noche', endsAfterDark: true),
          seat(
            'lejos-de-noche',
            walkDistance: WalkDistance.far,
            endsAfterDark: true,
          ),
          seat(
            'medio-con-escalera',
            walkDistance: WalkDistance.medium,
            hasStairs: true,
          ),
        ];

        expect(
          subject.eligibleSeatIds(
            const Needs({Need.walkALot, Need.returnAfterDark}),
            week,
          ),
          equals(['cerca-de-dia', 'medio-con-escalera']),
        );
      });

      test(
        'keeps only seats that pass every need when all four are marked',
        () {
          final week = [
            ...seats,
            seat('medium-plain', walkDistance: WalkDistance.medium),
          ];

          expect(
            subject.eligibleSeatIds(Needs(Need.values.toSet()), week),
            equals(['near', 'medium', 'medium-plain']),
          );
        },
      );

      group('with the invented demo seat facts', () {
        // The same file `scripts/seed.py` loads into the emulator, read
        // from the repo root.
        late Map<String, Object?> demoSeats;

        setUp(() {
          final file = File('../../data/demo/invented_seat_facts.json');
          final json = jsonDecode(file.readAsStringSync()) as Map;
          demoSeats = (json['seats']! as Map).cast<String, Object?>();
        });

        List<SeatFacts> seatsFor(String memberBarrio) => [
          for (final MapEntry(key: seatId, :value) in demoSeats.entries)
            if (value case {
              'blocksFrom': final Map<String, Object?> blocksFrom,
              'hasStairs': final bool hasStairs,
              'endsAfterDark': final bool endsAfterDark,
              'needsCar': final bool needsCar,
            })
              SeatFacts(
                seatId: seatId,
                walkDistance: WalkDistance.forMember(
                  memberBarrio: memberBarrio,
                  blocksFrom: blocksFrom.cast<String, num>(),
                ),
                hasStairs: hasStairs,
                endsAfterDark: endsAfterDark,
                needsCar: needsCar,
              ),
        ];

        test('reads every demo seat', () {
          expect(seatsFor('solymar-sur'), hasLength(demoSeats.length));
        });

        test('keeps only near and medium daytime seats for a member in '
            'solymar-sur for whom walking a lot and coming back at night '
            'are hard', () {
          expect(
            subject.eligibleSeatIds(
              const Needs({Need.walkALot, Need.returnAfterDark}),
              seatsFor('solymar-sur'),
            ),
            equals([
              'solymar-sur_mate_sat-afternoon',
              'solymar-sur_caminata_sat-morning',
              'solymar-norte_mate_sun-afternoon',
              'solymar-norte_truco_sat-afternoon',
            ]),
          );
        });

        test('keeps far seats when only coming back at night is hard', () {
          expect(
            subject.eligibleSeatIds(
              const Needs({Need.returnAfterDark}),
              seatsFor('solymar-sur'),
            ),
            equals([
              'solymar-sur_mate_sat-afternoon',
              'solymar-sur_caminata_sat-morning',
              'solymar-norte_mate_sun-afternoon',
              'solymar-norte_truco_sat-afternoon',
              'lomas-de-solymar_futbol5_sat-afternoon',
              'lagomar-sur_mate_sat-afternoon',
              'san-jose-de-carrasco_caminata_sun-afternoon',
              'shangrila_mate_sat-morning',
              'el-pinar-sur_futbol5_sat-afternoon',
              'el-pinar-norte_caminata_sun-afternoon',
            ]),
          );
        });

        test("measures the walk from the member's own barrio", () {
          expect(
            subject.eligibleSeatIds(
              const Needs({Need.walkALot, Need.returnAfterDark}),
              seatsFor('el-pinar-norte'),
            ),
            equals([
              'el-pinar-sur_futbol5_sat-afternoon',
              'el-pinar-norte_caminata_sun-afternoon',
            ]),
          );
        });
      });

      test('returns no ids when there are no seats', () {
        expect(
          subject.eligibleSeatIds(const Needs({Need.noCar}), const []),
          isEmpty,
        );
      });
    });
  });
}
