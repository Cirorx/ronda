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
      setUp(() {
        when(() => rondaApi.readUser(any())).thenAnswer((_) async => null);
      });

      test('keeps the time of the same version accepted before', () async {
        when(() => rondaApi.readUser('demo-uid')).thenAnswer(
          (_) async => UserDocument(
            terms: TermsRecord(version: '2026-10-27', acceptedAt: acceptedAt),
          ),
        );

        await subject.acceptTerms(
          'demo-uid',
          TermsAcceptance(
            version: '2026-10-27',
            acceptedAt: DateTime(2026, 11),
          ),
        );

        verifyNever(() => rondaApi.saveTerms(any(), any()));
      });

      test('records a newer version over an older one', () async {
        when(() => rondaApi.saveTerms(any(), any())).thenAnswer((_) async {});
        when(() => rondaApi.readUser('demo-uid')).thenAnswer(
          (_) async => UserDocument(
            terms: TermsRecord(version: '2026-01-01', acceptedAt: acceptedAt),
          ),
        );

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

      setUp(() {
        when(() => rondaApi.readUser(any())).thenAnswer((_) async => null);
      });

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

      test('keeps a profile already saved, writing nothing', () async {
        stubSave().thenAnswer((_) async {});
        when(() => rondaApi.readUser('demo-uid')).thenAnswer(
          (_) async => const UserDocument(
            firstName: 'Ana',
            ageBand: '30-39',
            barrio: 'cordon',
          ),
        );

        await subject.createProfile('demo-uid', profile);

        verifyNever(
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
      });

      test('saves over a document that holds only the terms', () async {
        stubSave().thenAnswer((_) async {});
        when(() => rondaApi.readUser('demo-uid')).thenAnswer(
          (_) async => UserDocument(
            terms: TermsRecord(version: '2026-10-27', acceptedAt: acceptedAt),
          ),
        );

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

      test('savedProfile reads the $Profile saved on users/{uid}', () async {
        when(() => rondaApi.readUser('demo-uid')).thenAnswer(
          (_) async => const UserDocument(
            firstName: 'Ana',
            ageBand: '30-39',
            barrio: 'cordon',
          ),
        );

        expect(
          await subject.savedProfile('demo-uid'),
          isA<Profile>().having((p) => p.firstName, 'firstName', 'Ana'),
        );
      });

      test('throws $SaveProfileFailure when the read fails', () {
        when(() => rondaApi.readUser('demo-uid'))
            .thenThrow(Exception('unavailable'));

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

        test('turns a place into a seat in every slot, ending after dark in '
            'the evening', () async {
          await firestore.collection('seat_facts').doc('palermo_mate').set({
            'barrio': 'palermo',
            'pretext': 'mate',
            'blocksFrom': {'palermo': 0, 'parque-rodo': 10.4},
            'hasStairs': false,
            'needsCar': false,
          });

          final seats = await subject.publishedSeats();

          expect(seats, hasLength(21));
          expect(
            seats.map((seat) => seat.seatId),
            containsAll([
              'palermo_mate_mon-morning',
              'palermo_mate_wed-evening',
              'palermo_mate_sun-evening',
            ]),
          );
          final wednesday = seats.singleWhere(
            (seat) => seat.seatId == 'palermo_mate_wed-evening',
          );
          expect(
            wednesday,
            equals(
              const PublishedSeat(
                seatId: 'palermo_mate_wed-evening',
                blocksFrom: {'palermo': 0, 'parque-rodo': 10.4},
                hasStairs: false,
                endsAfterDark: true,
                needsCar: false,
              ),
            ),
          );
          expect(
            seats
                .singleWhere(
                  (seat) => seat.seatId == 'palermo_mate_sat-morning',
                )
                .endsAfterDark,
            isFalse,
          );
        });

        test('lets a seat set for one slot replace its twin', () async {
          final seatFacts = firestore.collection('seat_facts');
          await seatFacts.doc('solymar-sur_mate').set({
            'barrio': 'solymar-sur',
            'pretext': 'mate',
            'blocksFrom': {'solymar-sur': 0},
            'hasStairs': false,
            'needsCar': false,
          });
          await seatFacts.doc('solymar-sur_mate_sat-afternoon').set({
            'barrio': 'solymar-sur',
            'pretext': 'mate',
            'slot': 'sat-afternoon',
            'blocksFrom': {'solymar-sur': 0},
            'hasStairs': true,
            'endsAfterDark': false,
            'needsCar': false,
          });

          final seats = await subject.publishedSeats();

          expect(seats, hasLength(21));
          expect(
            seats
                .singleWhere(
                  (seat) => seat.seatId == 'solymar-sur_mate_sat-afternoon',
                )
                .hasStairs,
            isTrue,
          );
        });
      });

      group('publishedSeatCatalogVersion', () {
        test('is null before the server published one', () async {
          expect(await subject.publishedSeatCatalogVersion(), isNull);
        });

        test('is the published version', () async {
          await firestore.doc('config/seat_catalog').set({'version': 'a1b2'});

          expect(await subject.publishedSeatCatalogVersion(), equals('a1b2'));
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

      test('publishedSeatCatalogVersion throws $ReadPublishedSeatsFailure', () {
        expect(
          subject.publishedSeatCatalogVersion,
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
