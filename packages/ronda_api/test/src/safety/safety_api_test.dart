import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

class _MockHttpsCallable extends Mock implements HttpsCallable;

class _MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<Object?>;

void main() {
  final at = DateTime.utc(2026, 11, 2, 15);
  final later = DateTime.utc(2026, 11, 3, 15);

  group(SafetyApi, () {
    late FakeFirebaseFirestore firestore;
    late FirebaseFunctions functions;
    late HttpsCallable callable;
    late HttpsCallableResult<Object?> result;
    late SafetyApi subject;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      functions = _MockFirebaseFunctions();
      callable = _MockHttpsCallable();
      result = _MockHttpsCallableResult();
      subject = SafetyApi(firestore: firestore, functions: functions);
      when(() => functions.httpsCallable(any())).thenReturn(callable);
      when(() => callable.call<Object?>(any<Object?>()))
          .thenAnswer((_) async => result);
      when(() => result.data).thenReturn(null);
    });

    group('people', () {
      test('reads who "¿Con quién?" offers', () async {
        when(() => result.data).thenReturn({
          'people': [
            {'uid': 'beto', 'firstName': 'Beto', 'rondaId': 'r1'},
          ],
        });

        final people = await subject.people();

        expect(people.single.uid, equals('beto'));
        expect(people.single.firstName, equals('Beto'));
        verify(() => functions.httpsCallable(SafetyApi.peopleCallable))
            .called(1);
      });

      test('throws on another shape', () async {
        await expectLater(subject.people(), throwsFormatException);
        when(() => result.data).thenReturn({
          'people': [
            {'uid': 3},
          ],
        });
        await expectLater(subject.people(), throwsFormatException);
      });
    });

    group('send', () {
      test('sends the words, the tags and who, and returns the id', () async {
        when(() => result.data).thenReturn({'reportId': 'rep1'});

        final id = await subject.send(
          text: 'Me molestó',
          tags: const ['bothered'],
          aboutUid: 'beto',
        );

        expect(id, equals('rep1'));
        verify(
          () => callable.call<Object?>({
            'text': 'Me molestó',
            'tags': ['bothered'],
            'aboutUid': 'beto',
          }),
        ).called(1);
      });

      test('throws on another shape', () async {
        await expectLater(
          subject.send(text: 'x', tags: const [], aboutUid: ''),
          throwsFormatException,
        );
      });
    });

    test('add, withdraw and every admin call name their callable', () async {
      await subject.add(reportId: 'rep1', text: 'más');
      await subject.withdraw('rep1');
      await subject.review(reportId: 'rep1', action: 'archive');
      await subject.separate('rep1');
      await subject.joinAgain('ana_beto');
      await subject.remove('rep1');
      await subject.letBackIn('beto');

      verifyInOrder([
        () => functions.httpsCallable(SafetyApi.addCallable),
        () => functions.httpsCallable(SafetyApi.withdrawCallable),
        () => functions.httpsCallable(SafetyApi.reviewCallable),
        () => functions.httpsCallable(SafetyApi.separateCallable),
        () => functions.httpsCallable(SafetyApi.joinAgainCallable),
        () => functions.httpsCallable(SafetyApi.removeCallable),
        () => functions.httpsCallable(SafetyApi.letBackInCallable),
      ]);
      verify(
        () => callable.call<Object?>({'reportId': 'rep1', 'action': 'archive'}),
      ).called(1);
      verify(() => callable.call<Object?>({'pairId': 'ana_beto'})).called(1);
      verify(() => callable.call<Object?>({'uid': 'beto'})).called(1);
    });

    test("watchReceipts reads the reporter's own, newest first", () async {
      await firestore.doc('users/ana/reports/old').set({
        'status': 'withdrawn',
        'createdAt': Timestamp.fromDate(at),
      });
      await firestore.doc('users/ana/reports/new').set({
        'status': 'open',
        'createdAt': Timestamp.fromDate(later),
      });

      final receipts = await subject.watchReceipts('ana').first;

      expect(receipts.map((r) => r.id), equals(['new', 'old']));
      expect(receipts.first.status, equals('open'));
      expect(receipts.last.createdAt.toUtc(), equals(at));
    });

    test('a receipt of another shape throws', () {
      expect(
        () => ReportReceiptDocument.fromJson('x', const {'status': 'open'}),
        throwsFormatException,
      );
    });

    group('watchReports', () {
      test('reads every report with its additions, newest first', () async {
        await firestore.doc('reports/rep1').set({
          'reporterUid': 'ana',
          'reporterName': 'Ana',
          'aboutUid': 'beto',
          'aboutName': 'Beto',
          'rondaLine': 'Sábado a la tarde · mate en la rambla',
          'tags': ['bothered', 7],
          'text': 'Me molestó',
          'additions': [
            {'text': 'Y el jueves', 'at': Timestamp.fromDate(later)},
            {'text': 'sin fecha'},
          ],
          'status': 'open',
          'withdrawnAt': Timestamp.fromDate(later),
          'unread': true,
          'createdAt': Timestamp.fromDate(at),
        });
        await firestore.doc('reports/rep2').set({
          'reporterUid': 'cora',
          'aboutUid': '',
          'status': 'archived',
          'withdrawnAt': null,
          'createdAt': Timestamp.fromDate(later),
        });

        final reports = await subject.watchReports().first;

        expect(reports.map((r) => r.id), equals(['rep2', 'rep1']));
        final first = reports.last;
        expect(first.tags, equals(['bothered']));
        expect(first.additions.single.text, equals('Y el jueves'));
        expect(first.additions.single.at.toUtc(), equals(later));
        expect(first.withdrawn, isTrue);
        expect(first.unread, isTrue);
        expect(first.rondaLine, contains('mate'));
        final second = reports.first;
        expect(second.reporterName, isEmpty);
        expect(second.tags, isEmpty);
        expect(second.additions, isEmpty);
        expect(second.withdrawn, isFalse);
        expect(second.unread, isFalse);
      });

      test('a report of another shape throws', () {
        expect(
          () => ReportDocument.fromJson('x', const {'status': 'open'}),
          throwsFormatException,
        );
      });
    });

    test('watchUnreadCount counts the unread reports only', () async {
      await firestore.doc('reports/a').set({'unread': true});
      await firestore.doc('reports/b').set({'unread': false});
      await firestore.doc('reports/c').set({'unread': true});

      expect(await subject.watchUnreadCount().first, equals(2));
    });

    test('watchAvoidPairs reads each pair and where they still sit', () async {
      await firestore.doc('avoid/ana_beto').set({
        'uidA': 'ana',
        'uidB': 'beto',
        'nameA': 'Ana',
        'nameB': 'Beto',
        'together': {'rondaId': 'r1', 'line': 'Sábado a la tarde'},
      });
      await firestore.doc('avoid/cora_dani').set({
        'uidA': 'cora',
        'uidB': 'dani',
        'together': null,
      });

      final pairs = await subject.watchAvoidPairs().first;

      expect(pairs.first.togetherLine, equals('Sábado a la tarde'));
      expect(pairs.first.nameB, equals('Beto'));
      expect(pairs.last.togetherLine, isNull);
      expect(pairs.last.nameA, isEmpty);
      expect(
        () => AvoidPairDocument.fromJson('x', const {'uidA': 'a'}),
        throwsFormatException,
      );
    });

    test('watchRemoved reads who is out of Ronda', () async {
      await firestore.doc('removed/beto').set({
        'firstName': 'Beto',
        'at': Timestamp.fromDate(at),
        'notice': 'sent',
      });

      final removed = (await subject.watchRemoved().first).single;

      expect(removed.uid, equals('beto'));
      expect(removed.firstName, equals('Beto'));
      expect(removed.at.toUtc(), equals(at));
      expect(removed.notice, equals('sent'));
      expect(
        () => RemovedDocument.fromJson('x', const {}),
        throwsFormatException,
      );
    });
  });
}
