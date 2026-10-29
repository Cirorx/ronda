import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFirebaseStorage extends Mock implements FirebaseStorage;

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

void main() {
  group(RondaApi, () {
    late FakeFirebaseFirestore firestore;
    late RondaApi subject;

    final acceptedAt = DateTime(2026, 10, 27, 18, 30);

    setUp(() {
      firestore = FakeFirebaseFirestore();
      subject = RondaApi(
        firestore: firestore,
        storage: _MockFirebaseStorage(),
        functions: _MockFirebaseFunctions(),
      );
    });

    Future<Map<String, dynamic>?> readUser(String uid) async =>
        (await firestore.collection('users').doc(uid).get()).data();

    test('pins every function to southamerica-east1', () {
      expect(RondaApi.region, equals('southamerica-east1'));
    });

    group('watchUser', () {
      test('emits null when users/{uid} does not exist', () {
        expect(subject.watchUser('demo-uid'), emits(isNull));
      });

      test('emits the $UserDocument stored at users/{uid}', () async {
        await firestore.collection('users').doc('demo-uid').set({
          'firstName': 'Marta',
          'ageBand': '60-69',
          'barrio': 'solymar-norte',
          'slots': ['thu-afternoon'],
          'pretexts': ['mate'],
          'brings': ['termo'],
          'terms': {
            'version': '2026-10-27',
            'acceptedAt': Timestamp.fromDate(acceptedAt),
          },
          'createdAt': Timestamp.fromDate(acceptedAt),
        });

        expect(
          subject.watchUser('demo-uid'),
          emits(
            UserDocument(
              firstName: 'Marta',
              ageBand: '60-69',
              barrio: 'solymar-norte',
              slots: const ['thu-afternoon'],
              pretexts: const ['mate'],
              brings: const ['termo'],
              terms: TermsRecord(version: '2026-10-27', acceptedAt: acceptedAt),
              createdAt: acceptedAt,
            ),
          ),
        );
      });

      test('emits again once the profile lands on the terms', () async {
        await subject.saveTerms(
          'demo-uid',
          TermsRecord(version: '2026-10-27', acceptedAt: acceptedAt),
        );
        final expectation = expectLater(
          subject.watchUser('demo-uid').map((user) => user?.firstName),
          emitsInOrder([isNull, equals('Marta')]),
        );
        await Future<void>.delayed(Duration.zero);

        await firestore.collection('users').doc('demo-uid').update({
          'firstName': 'Marta',
        });

        await expectation;
      });

      test('reads only the given uid', () async {
        await firestore.collection('users').doc('other-uid').set({
          'firstName': 'Julio',
        });

        expect(subject.watchUser('demo-uid'), emits(isNull));
      });
    });

    group('saveTerms', () {
      test('creates users/{uid} with only the terms', () async {
        await subject.saveTerms(
          'demo-uid',
          TermsRecord(version: '2026-10-27', acceptedAt: acceptedAt),
        );

        expect(
          await readUser('demo-uid'),
          equals({
            'terms': {
              'version': '2026-10-27',
              'acceptedAt': Timestamp.fromDate(acceptedAt),
            },
          }),
        );
      });

      test('keeps the profile fields already there', () async {
        await firestore.collection('users').doc('demo-uid').set({
          'firstName': 'Marta',
        });

        await subject.saveTerms(
          'demo-uid',
          TermsRecord(version: '2026-10-27', acceptedAt: acceptedAt),
        );

        expect(await readUser('demo-uid'), containsPair('firstName', 'Marta'));
      });
    });

    group('saveProfile', () {
      Future<void> save() => subject.saveProfile(
        'demo-uid',
        firstName: 'Marta',
        ageBand: '60-69',
        barrio: 'solymar-norte',
        slots: const ['thu-afternoon', 'sat-morning'],
        pretexts: const ['mate', 'truco'],
        brings: const ['termo'],
      );

      test('writes the profile fields and a server createdAt', () async {
        await save();

        final user = await readUser('demo-uid');
        expect(
          user,
          allOf(
            containsPair('firstName', 'Marta'),
            containsPair('ageBand', '60-69'),
            containsPair('barrio', 'solymar-norte'),
            containsPair('slots', ['thu-afternoon', 'sat-morning']),
            containsPair('pretexts', ['mate', 'truco']),
            containsPair('brings', ['termo']),
          ),
        );
        expect(user?['createdAt'], isA<Timestamp>());
      });

      test('keeps the terms recorded before', () async {
        await subject.saveTerms(
          'demo-uid',
          TermsRecord(version: '2026-10-27', acceptedAt: acceptedAt),
        );

        await save();

        expect(
          await readUser('demo-uid'),
          containsPair('terms', {
            'version': '2026-10-27',
            'acceptedAt': Timestamp.fromDate(acceptedAt),
          }),
        );
      });

      test('never writes needs, mood or audio', () async {
        await save();

        expect(
          (await readUser('demo-uid'))?.keys,
          isNot(anyOf(contains('needs'), contains('mood'), contains('audio'))),
        );
      });
    });
  });
}
