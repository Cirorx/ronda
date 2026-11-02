import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_store/device_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockRondaApi extends Mock implements RondaApi;

class _MockFirebaseStorage extends Mock implements FirebaseStorage;

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

class _MockDeviceStore extends Mock implements DeviceStore;

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
      subject = ProfileRepository(
        rondaApi: rondaApi,
        deviceStore: _MockDeviceStore(),
      );
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
              barrio: 'las-piedras',
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

      test('emits casa with its neighbours and trabajo, dropping an unknown '
          'trabajo', () {
        when(() => rondaApi.watchUser('demo-uid')).thenAnswer(
          (_) => Stream.fromIterable(const [
            UserDocument(
              firstName: 'Marta',
              ageBand: '60-69',
              barrio: 'cordon',
              barrioNeighbours: true,
              workBarrio: 'centro',
              workBarrioNeighbours: true,
            ),
            UserDocument(
              firstName: 'Marta',
              ageBand: '60-69',
              barrio: 'cordon',
              workBarrio: 'atlantida',
            ),
          ]),
        );

        expect(
          subject.watchProfile('demo-uid'),
          emitsInOrder([
            isA<Profile>()
                .having((p) => p.barrioNeighbours, 'barrioNeighbours', isTrue)
                .having(
                  (p) => p.work,
                  'work',
                  const Anchor(barrio: Barrio.centro, neighbours: true),
                ),
            isA<Profile>().having((p) => p.work, 'work', isNull),
          ]),
        );
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
          barrioNeighbours: any(named: 'barrioNeighbours'),
          workBarrio: any(named: 'workBarrio'),
          workBarrioNeighbours: any(named: 'workBarrioNeighbours'),
          slots: any(named: 'slots'),
          pretexts: any(named: 'pretexts'),
          brings: any(named: 'brings'),
          isNew: any(named: 'isNew'),
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

      test('updateProfile writes casa, trabajo and their neighbours, keeping '
          'createdAt', () async {
        stubSave().thenAnswer((_) async {});

        await subject.updateProfile(
          'demo-uid',
          const Profile(
            firstName: 'Marta',
            ageBand: AgeBand.sixties,
            barrio: Barrio.cordon,
            barrioNeighbours: true,
            pretexts: {},
            slots: {},
            brings: {},
            work: Anchor(barrio: Barrio.centro, neighbours: true),
          ),
        );

        verify(
          () => rondaApi.saveProfile(
            'demo-uid',
            firstName: 'Marta',
            ageBand: '60-69',
            barrio: 'cordon',
            barrioNeighbours: true,
            workBarrio: 'centro',
            workBarrioNeighbours: true,
            slots: [],
            pretexts: [],
            brings: [],
            isNew: false,
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

    // EligibleSeatsApi is an extension, which mocktail can't stub: these
    // tests read and write through a real RondaApi over a fake Firestore.
    group('over a fake Firestore', () {
      late FakeFirebaseFirestore firestore;

      setUp(() {
        firestore = FakeFirebaseFirestore();
        subject = ProfileRepository(
          rondaApi: RondaApi(
            firestore: firestore,
            storage: _MockFirebaseStorage(),
            functions: _MockFirebaseFunctions(),
          ),
          deviceStore: _MockDeviceStore(),
        );
      });

      group('publishedSeats', () {
        test('maps every seat_facts document to a $PublishedSeat', () async {
          await firestore
              .collection('seat_facts')
              .doc('solymar-sur_mate_sat-afternoon')
              .set({
                'barrio': 'solymar-sur',
                'pretext': 'mate',
                'slot': 'sat-afternoon',
                'blocksFrom': {'solymar-sur': 0, 'solymar-norte': 9.1},
                'hasStairs': false,
                'endsAfterDark': false,
                'needsCar': true,
              });
          await firestore.collection('seat_facts').doc('broken').set({
            'barrio': 'solymar-sur',
          });

          expect(
            await subject.publishedSeats(),
            equals([
              const PublishedSeat(
                seatId: 'solymar-sur_mate_sat-afternoon',
                blocksFrom: {'solymar-sur': 0, 'solymar-norte': 9.1},
                hasStairs: false,
                endsAfterDark: false,
                needsCar: true,
              ),
            ]),
          );
        });

        test('returns no seats when none is published', () async {
          expect(await subject.publishedSeats(), isEmpty);
        });
      });

      group('saveEligibleSeatIds', () {
        test(
          'writes exactly seatIds and updatedAt to private/eligible',
          () async {
            await subject.saveEligibleSeatIds(
              uid: 'demo-uid',
              seatIds: const [
                'solymar-sur_mate_sat-afternoon',
                'solymar-norte_truco_sat-afternoon',
              ],
            );

            final eligible = await firestore
                .doc('users/demo-uid/private/eligible')
                .get();
            expect(
              eligible.data()?.keys,
              unorderedEquals(['seatIds', 'updatedAt']),
            );
            expect(
              eligible.data()?['seatIds'],
              equals([
                'solymar-sur_mate_sat-afternoon',
                'solymar-norte_truco_sat-afternoon',
              ]),
            );
            expect(eligible.data()?['updatedAt'], isA<Timestamp>());
            final user = await firestore.doc('users/demo-uid').get();
            expect(user.exists, isFalse);
          },
        );
      });
    });

    group('when Firestore fails', () {
      setUp(() {
        when(() => rondaApi.firestore).thenThrow(Exception('unavailable'));
      });

      test('publishedSeats throws $ReadPublishedSeatsFailure', () {
        expect(
          subject.publishedSeats,
          throwsA(isA<ReadPublishedSeatsFailure>()),
        );
      });

      test('saveEligibleSeatIds throws $SaveEligibleSeatIdsFailure', () {
        expect(
          () => subject.saveEligibleSeatIds(uid: 'demo-uid', seatIds: const []),
          throwsA(isA<SaveEligibleSeatIdsFailure>()),
        );
      });
    });
  });
}
