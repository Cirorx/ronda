import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockRondaApi extends Mock implements RondaApi;

void main() {
  group(ProfileRepository, () {
    late RondaApi rondaApi;
    late ProfileRepository subject;

    final acceptedAt = DateTime(2026, 10, 27, 18, 30);

    final profile = Profile(
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

    setUpAll(() {
      registerFallbackValue(
        TermsRecord(version: '', acceptedAt: DateTime(2026)),
      );
    });

    setUp(() {
      rondaApi = _MockRondaApi();
      subject = ProfileRepository(rondaApi: rondaApi);
    });

    group('watchProfile', () {
      test('emits null while users/{uid} does not exist', () {
        when(() => rondaApi.watchUser('demo-uid'))
            .thenAnswer((_) => Stream.value(null));

        expect(subject.watchProfile('demo-uid'), emits(isNull));
      });

      test('emits null while the document holds only the terms', () {
        when(() => rondaApi.watchUser('demo-uid')).thenAnswer(
          (_) => Stream.value(
            UserDocument(
              terms: TermsRecord(version: '2026-10-27', acceptedAt: acceptedAt),
            ),
          ),
        );

        expect(subject.watchProfile('demo-uid'), emits(isNull));
      });

      test('emits null when a required field is empty or unknown', () {
        when(() => rondaApi.watchUser('demo-uid')).thenAnswer(
          (_) => Stream.fromIterable(const [
            UserDocument(
              firstName: '',
              ageBand: '60-69',
              barrio: 'solymar-norte',
            ),
            UserDocument(
              firstName: 'Marta',
              ageBand: '65',
              barrio: 'solymar-norte',
            ),
            UserDocument(
              firstName: 'Marta',
              ageBand: '60-69',
              barrio: 'pocitos',
            ),
          ]),
        );

        expect(
          subject.watchProfile('demo-uid'),
          emitsInOrder([isNull, isNull, isNull]),
        );
      });

      test('emits the $Profile once onboarding saved it, dropping unknown '
          'ids', () {
        when(() => rondaApi.watchUser('demo-uid')).thenAnswer(
          (_) => Stream.value(
            const UserDocument(
              firstName: 'Marta',
              ageBand: '60-69',
              barrio: 'solymar-norte',
              slots: ['thu-afternoon', 'sat-morning', 'sat-night'],
              pretexts: ['mate', 'truco', 'ajedrez'],
              brings: ['termo', 'tengo-ganas', 'plata'],
            ),
          ),
        );

        expect(subject.watchProfile('demo-uid'), emits(profile));
      });
    });

    group('acceptTerms', () {
      test('writes the version and time through ronda_api', () async {
        when(() => rondaApi.saveTerms(any(), any())).thenAnswer((_) async {});

        await subject.acceptTerms(
          'demo-uid',
          TermsAcceptance(version: '2026-10-27', acceptedAt: acceptedAt),
        );

        verify(
          () => rondaApi.saveTerms(
            'demo-uid',
            TermsRecord(version: '2026-10-27', acceptedAt: acceptedAt),
          ),
        ).called(1);
      });

      test('throws $AcceptTermsFailure when the write fails', () {
        when(() => rondaApi.saveTerms(any(), any()))
            .thenThrow(Exception('permission-denied'));

        expect(
          () => subject.acceptTerms(
            'demo-uid',
            TermsAcceptance(version: '2026-10-27', acceptedAt: acceptedAt),
          ),
          throwsA(isA<AcceptTermsFailure>()),
        );
      });
    });

    group('createProfile', () {
      When<Future<void>> stubSave() => when(
        () => rondaApi.saveProfile(
          any(),
          firstName: any(named: 'firstName'),
          ageBand: any(named: 'ageBand'),
          barrio: any(named: 'barrio'),
          slots: any(named: 'slots'),
          pretexts: any(named: 'pretexts'),
          brings: any(named: 'brings'),
        ),
      );

      test('writes the ids in declaration order', () async {
        stubSave().thenAnswer((_) async {});

        await subject.createProfile('demo-uid', profile);

        verify(
          () => rondaApi.saveProfile(
            'demo-uid',
            firstName: 'Marta',
            ageBand: '60-69',
            barrio: 'solymar-norte',
            slots: ['thu-afternoon', 'sat-morning'],
            pretexts: ['mate', 'truco'],
            brings: ['termo', 'tengo-ganas'],
          ),
        ).called(1);
      });

      test('throws $SaveProfileFailure when the write fails', () {
        stubSave().thenThrow(Exception('unavailable'));

        expect(
          () => subject.createProfile('demo-uid', profile),
          throwsA(isA<SaveProfileFailure>()),
        );
      });
    });
  });
}
