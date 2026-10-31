import 'dart:convert';

import 'package:device_store/device_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockRondaApi extends Mock implements RondaApi;

class _MockDeviceStore extends Mock implements DeviceStore;

/// A device store that keeps its values in memory.
class _FakeDeviceStore extends Fake implements DeviceStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  group('ProfileRepository on this phone', () {
    late _FakeDeviceStore deviceStore;
    late ProfileRepository subject;

    final terms = TermsAcceptance(
      version: '2026-10-27',
      acceptedAt: DateTime(2026, 10, 29, 23, 55),
    );

    final answers = Profile(
      firstName: 'Marta',
      ageBand: AgeBand.sixties,
      barrio: Barrio.solymarNorte,
      pretexts: const {Pretext.truco, Pretext.mate},
      slots: {
        const Slot(SlotDay.saturday, SlotBand.morning),
        const Slot(SlotDay.thursday, SlotBand.afternoon),
      },
      brings: const {Bring.tengoGanas, Bring.termo},
    );

    setUp(() {
      deviceStore = _FakeDeviceStore();
      subject = ProfileRepository(
        rondaApi: _MockRondaApi(),
        deviceStore: deviceStore,
      );
    });

    group('holdTerms', () {
      test('keeps the version and the time, in UTC', () async {
        await subject.holdTerms(terms);

        expect(
          jsonDecode(deviceStore.values[ProfileRepository.heldTermsKey]!),
          equals({
            'version': '2026-10-27',
            'acceptedAt': terms.acceptedAt.toUtc().toIso8601String(),
          }),
        );
      });
    });

    group('heldTerms', () {
      test('returns what holdTerms kept', () async {
        await subject.holdTerms(terms);

        expect(await subject.heldTerms(), equals(terms));
      });

      test('returns null when nothing is held', () async {
        expect(await subject.heldTerms(), isNull);
      });

      test('returns null for a value of another shape', () async {
        deviceStore.values[ProfileRepository.heldTermsKey] = '{"version": 1}';

        expect(await subject.heldTerms(), isNull);
      });

      test('returns null for a time it cannot read', () async {
        deviceStore.values[ProfileRepository.heldTermsKey] = jsonEncode({
          'version': '2026-10-27',
          'acceptedAt': 'yesterday',
        });

        expect(await subject.heldTerms(), isNull);
      });

      test('returns null for a value that is not JSON', () async {
        deviceStore.values[ProfileRepository.heldTermsKey] = 'nope';

        expect(await subject.heldTerms(), isNull);
      });
    });

    group('clearHeldTerms', () {
      test('deletes the held conditions', () async {
        await subject.holdTerms(terms);

        await subject.clearHeldTerms();

        expect(await subject.heldTerms(), isNull);
      });
    });

    group('holdAnswers', () {
      test('keeps the answers as ids, lists in declaration order', () async {
        await subject.holdAnswers(answers);

        expect(
          jsonDecode(deviceStore.values[ProfileRepository.heldAnswersKey]!),
          equals({
            'firstName': 'Marta',
            'ageBand': '60-69',
            'barrio': 'solymar-norte',
            'pretexts': ['mate', 'truco'],
            'slots': ['thu-afternoon', 'sat-morning'],
            'brings': ['termo', 'tengo-ganas'],
          }),
        );
      });
    });

    group('heldAnswers', () {
      test('returns what holdAnswers kept', () async {
        await subject.holdAnswers(answers);

        expect(await subject.heldAnswers(), equals(answers));
      });

      test('returns null when nothing is held', () async {
        expect(await subject.heldAnswers(), isNull);
      });

      test('drops ids nobody stores', () async {
        deviceStore.values[ProfileRepository.heldAnswersKey] = jsonEncode({
          'firstName': 'Marta',
          'ageBand': '60-69',
          'barrio': 'solymar-norte',
          'pretexts': ['mate', 'bochas', 3],
          'slots': ['sat-morning', 'sat-night'],
          'brings': ['termo', 'asado'],
        });

        expect(
          await subject.heldAnswers(),
          equals(
            Profile(
              firstName: 'Marta',
              ageBand: AgeBand.sixties,
              barrio: Barrio.solymarNorte,
              pretexts: const {Pretext.mate},
              slots: {const Slot(SlotDay.saturday, SlotBand.morning)},
              brings: const {Bring.termo},
            ),
          ),
        );
      });

      for (final (name, change) in [
        ('an unknown age band', {'ageBand': '20s'}),
        ('an unknown barrio', {'barrio': 'pocitos'}),
        ('an empty first name', {'firstName': ''}),
        ('a missing list', {'brings': null}),
      ]) {
        test('returns null for $name', () async {
          deviceStore.values[ProfileRepository.heldAnswersKey] = jsonEncode({
            'firstName': 'Marta',
            'ageBand': '60-69',
            'barrio': 'solymar-norte',
            'pretexts': ['mate'],
            'slots': ['sat-morning'],
            'brings': ['termo'],
            ...change,
          });

          expect(await subject.heldAnswers(), isNull);
        });
      }
    });

    group('clearHeldAnswers', () {
      test('deletes the held answers', () async {
        await subject.holdAnswers(answers);

        await subject.clearHeldAnswers();

        expect(await subject.heldAnswers(), isNull);
      });
    });

    group('walkthroughSeen', () {
      test('is false before "¿Cómo funciona?" was shown', () async {
        expect(await subject.walkthroughSeen(), isFalse);
      });

      test('is true once markWalkthroughSeen ran', () async {
        await subject.markWalkthroughSeen();

        expect(await subject.walkthroughSeen(), isTrue);
        expect(
          deviceStore.values[ProfileRepository.walkthroughSeenKey],
          equals('true'),
        );
      });

      test('is false for anything else under its key', () async {
        deviceStore.values[ProfileRepository.walkthroughSeenKey] = '"yes"';

        expect(await subject.walkthroughSeen(), isFalse);
      });
    });

    group('when the device store fails', () {
      late DeviceStore failing;

      setUp(() {
        failing = _MockDeviceStore();
        when(() => failing.read(any())).thenThrow(Exception('keystore'));
        when(() => failing.write(any(), any()))
            .thenThrow(Exception('keystore'));
        when(() => failing.delete(any())).thenThrow(Exception('keystore'));
        subject = ProfileRepository(
          rondaApi: _MockRondaApi(),
          deviceStore: failing,
        );
      });

      test('holdTerms throws $HoldOnPhoneFailure', () {
        expect(subject.holdTerms(terms), throwsA(isA<HoldOnPhoneFailure>()));
      });

      test('holdAnswers throws $HoldOnPhoneFailure', () {
        expect(
          subject.holdAnswers(answers),
          throwsA(isA<HoldOnPhoneFailure>()),
        );
      });

      test('clearHeldTerms throws $HoldOnPhoneFailure', () {
        expect(subject.clearHeldTerms(), throwsA(isA<HoldOnPhoneFailure>()));
      });

      test('clearHeldAnswers throws $HoldOnPhoneFailure', () {
        expect(subject.clearHeldAnswers(), throwsA(isA<HoldOnPhoneFailure>()));
      });

      test('markWalkthroughSeen throws $HoldOnPhoneFailure', () {
        expect(
          subject.markWalkthroughSeen(),
          throwsA(isA<HoldOnPhoneFailure>()),
        );
      });

      test('walkthroughSeen is false', () async {
        expect(await subject.walkthroughSeen(), isFalse);
      });

      test('heldTerms and heldAnswers return null', () async {
        expect(await subject.heldTerms(), isNull);
        expect(await subject.heldAnswers(), isNull);
      });
    });
  });
}
