import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:safety_repository/safety_repository.dart';

class _MockSafetyApi extends Mock implements SafetyApi;

final _at = DateTime.utc(2026, 11, 2, 15);

FirebaseException _error(String code) =>
    FirebaseException(plugin: 'cloud_functions', code: code);

ReportDocument _report({
  String status = 'open',
  List<String> tags = const ['bothered', 'unknown', 'minor'],
}) => ReportDocument(
  id: 'rep1',
  reporterUid: 'ana',
  reporterName: 'Ana',
  aboutUid: 'beto',
  aboutName: 'Beto',
  rondaLine: 'Sábado a la tarde · mate en la rambla',
  tags: tags,
  text: 'Me molestó',
  additions: [ReportAdditionDocument(text: 'Y el jueves', at: _at)],
  status: status,
  withdrawn: true,
  unread: true,
  createdAt: _at,
);

void main() {
  group(SafetyRepository, () {
    late SafetyApi api;
    late SafetyRepository subject;

    setUp(() {
      api = _MockSafetyApi();
      subject = SafetyRepository(safetyApi: api);
    });

    group('reportPeople', () {
      test('reads who "¿Con quién?" offers', () async {
        when(api.people).thenAnswer(
          (_) async => const [
            ReportPersonDocument(uid: 'b', firstName: 'Beto'),
          ],
        );

        expect(
          await subject.reportPeople(),
          equals(const [ReportPerson(uid: 'b', firstName: 'Beto')]),
        );
      });

      test('a refusal is forbidden', () {
        when(api.people).thenThrow(_error('unauthenticated'));

        expect(
          subject.reportPeople,
          throwsA(
            isA<SafetyFailure>().having(
              (f) => f.reason,
              'reason',
              SafetyFailureReason.forbidden,
            ),
          ),
        );
      });
    });

    group('sendReport', () {
      setUp(() {
        when(
          () => api.send(
            text: any(named: 'text'),
            tags: any(named: 'tags'),
            aboutUid: any(named: 'aboutUid'),
          ),
        ).thenAnswer((_) async => 'rep1');
      });

      test("sends the tags' ids in the spec's order", () async {
        final id = await subject.sendReport(
          text: 'Me molestó',
          tags: {ReportTag.other, ReportTag.askedForMoney},
          aboutUid: '',
        );

        expect(id, equals('rep1'));
        verify(
          () => api.send(
            text: 'Me molestó',
            tags: ['askedForMoney', 'other'],
            aboutUid: '',
          ),
        ).called(1);
      });

      test('too many in a day is tooMany', () {
        when(
          () => api.send(
            text: any(named: 'text'),
            tags: any(named: 'tags'),
            aboutUid: any(named: 'aboutUid'),
          ),
        ).thenThrow(_error('resource-exhausted'));

        expect(
          () => subject.sendReport(text: 'x', tags: const {}, aboutUid: ''),
          throwsA(
            isA<SafetyFailure>().having(
              (f) => f.reason,
              'reason',
              SafetyFailureReason.tooMany,
            ),
          ),
        );
      });
    });

    test('each call reaches its callable', () async {
      when(
        () => api.add(
          reportId: any(named: 'reportId'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) async {});
      when(() => api.withdraw(any())).thenAnswer((_) async {});
      when(
        () => api.review(
          reportId: any(named: 'reportId'),
          action: any(named: 'action'),
        ),
      ).thenAnswer((_) async {});
      when(() => api.separate(any())).thenAnswer((_) async {});
      when(() => api.joinAgain(any())).thenAnswer((_) async {});
      when(() => api.remove(any())).thenAnswer((_) async {});
      when(() => api.letBackIn(any())).thenAnswer((_) async {});

      await subject.addToReport(reportId: 'rep1', text: 'más');
      await subject.withdrawReport('rep1');
      await subject.markRead('rep1');
      await subject.archive('rep1');
      await subject.reopen('rep1');
      await subject.separate('rep1');
      await subject.joinAgain('ana_beto');
      await subject.remove('rep1');
      await subject.letBackIn('beto');

      verify(() => api.add(reportId: 'rep1', text: 'más')).called(1);
      verify(() => api.withdraw('rep1')).called(1);
      for (final action in ['read', 'archive', 'reopen']) {
        verify(() => api.review(reportId: 'rep1', action: action)).called(1);
      }
      verify(() => api.separate('rep1')).called(1);
      verify(() => api.joinAgain('ana_beto')).called(1);
      verify(() => api.remove('rep1')).called(1);
      verify(() => api.letBackIn('beto')).called(1);
    });

    test('a step that no longer applies is gone, anything else other', () {
      when(() => api.remove(any())).thenThrow(_error('already-exists'));
      when(() => api.withdraw(any())).thenThrow(Exception('offline'));

      expect(
        () => subject.remove('rep1'),
        throwsA(
          isA<SafetyFailure>().having(
            (f) => f.reason,
            'reason',
            SafetyFailureReason.gone,
          ),
        ),
      );
      expect(
        () => subject.withdrawReport('rep1'),
        throwsA(
          isA<SafetyFailure>().having(
            (f) => f.reason,
            'reason',
            SafetyFailureReason.other,
          ),
        ),
      );
    });

    test('watchReceipts reads whether each was withdrawn', () {
      when(() => api.watchReceipts('ana')).thenAnswer(
        (_) => Stream.value([
          ReportReceiptDocument(id: 'a', status: 'open', createdAt: _at),
          ReportReceiptDocument(id: 'b', status: 'withdrawn', createdAt: _at),
        ]),
      );

      expect(
        subject.watchReceipts('ana'),
        emits([
          ReportReceipt(id: 'a', createdAt: _at),
          ReportReceipt(id: 'b', createdAt: _at, withdrawn: true),
        ]),
      );
    });

    group('watchQueue', () {
      test('joins the reports, the pairs and who is out', () {
        when(api.watchReports).thenAnswer(
          (_) => Stream.value([_report(), _report(status: 'archived')]),
        );
        when(api.watchAvoidPairs).thenAnswer(
          (_) => Stream.value(const [
            AvoidPairDocument(
              id: 'ana_beto',
              uidA: 'ana',
              uidB: 'beto',
              nameA: 'Ana',
              nameB: 'Beto',
              togetherLine: 'Sábado a la tarde',
            ),
          ]),
        );
        when(api.watchRemoved).thenAnswer(
          (_) => Stream.value([
            RemovedDocument(
              uid: 'beto',
              firstName: 'Beto',
              at: _at,
              notice: 'pending',
            ),
            RemovedDocument(uid: 'x', firstName: 'X', at: _at, notice: '?'),
          ]),
        );

        expect(
          subject.watchQueue(),
          emits(
            SafetyQueue(
              reports: [
                Report(
                  id: 'rep1',
                  reporterUid: 'ana',
                  reporterName: 'Ana',
                  aboutUid: 'beto',
                  aboutName: 'Beto',
                  createdAt: _at,
                  rondaLine: 'Sábado a la tarde · mate en la rambla',
                  tags: const [ReportTag.bothered, ReportTag.minor],
                  text: 'Me molestó',
                  additions: [ReportAddition(text: 'Y el jueves', at: _at)],
                  withdrawn: true,
                  unread: true,
                ),
                Report(
                  id: 'rep1',
                  reporterUid: 'ana',
                  reporterName: 'Ana',
                  aboutUid: 'beto',
                  aboutName: 'Beto',
                  createdAt: _at,
                  rondaLine: 'Sábado a la tarde · mate en la rambla',
                  tags: const [ReportTag.bothered, ReportTag.minor],
                  text: 'Me molestó',
                  additions: [ReportAddition(text: 'Y el jueves', at: _at)],
                  archived: true,
                  withdrawn: true,
                  unread: true,
                ),
              ],
              separated: const [
                SeparatedPair(
                  id: 'ana_beto',
                  uidA: 'ana',
                  uidB: 'beto',
                  nameA: 'Ana',
                  nameB: 'Beto',
                  togetherLine: 'Sábado a la tarde',
                ),
              ],
              removed: [
                RemovedPerson(
                  uid: 'beto',
                  firstName: 'Beto',
                  at: _at,
                  notice: RemovalNotice.pending,
                ),
                RemovedPerson(uid: 'x', firstName: 'X', at: _at),
              ],
            ),
          ),
        );
      });

      test('a refused read is forbidden', () {
        when(api.watchReports)
            .thenAnswer((_) => Stream.error(_error('permission-denied')));
        when(api.watchAvoidPairs).thenAnswer((_) => Stream.value(const []));
        when(api.watchRemoved).thenAnswer((_) => Stream.value(const []));

        expect(
          subject.watchQueue(),
          emitsError(
            isA<SafetyFailure>().having(
              (f) => f.reason,
              'reason',
              SafetyFailureReason.forbidden,
            ),
          ),
        );
      });
    });

    test('watchUnreadCount passes the count through', () {
      when(api.watchUnreadCount).thenAnswer((_) => Stream.value(2));

      expect(subject.watchUnreadCount(), emits(2));
    });
  });

  group(SeparatedPair, () {
    test('joins the same two in either order', () {
      const pair = SeparatedPair(id: 'a_b', uidA: 'a', uidB: 'b');

      expect(pair.joins('a', 'b'), isTrue);
      expect(pair.joins('b', 'a'), isTrue);
      expect(pair.joins('a', 'c'), isFalse);
    });
  });

  group(Report, () {
    test('is about someone from outside when it names nobody', () {
      final outside = Report(
        id: 'r',
        reporterUid: 'a',
        reporterName: 'Ana',
        aboutUid: '',
        aboutName: '',
        createdAt: _at,
      );

      expect(outside.aboutOutsider, isTrue);
    });
  });
}
