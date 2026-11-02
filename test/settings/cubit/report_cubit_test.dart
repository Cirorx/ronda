import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/settings/cubit/report_cubit.dart';
import 'package:ronda/settings/models/report_text.dart';
import 'package:safety_repository/safety_repository.dart';

class _MockSafetyRepository extends Mock implements SafetyRepository;

const _people = [ReportPerson(uid: 'beto', firstName: 'Beto')];
final _receipt = ReportReceipt(id: 'rep1', createdAt: DateTime.utc(2026, 11));

void main() {
  group(ReportCubit, () {
    late SafetyRepository repository;

    setUpAll(() => registerFallbackValue(<ReportTag>{}));

    setUp(() {
      repository = _MockSafetyRepository();
      when(() => repository.watchReceipts('ana'))
          .thenAnswer((_) => Stream.value([_receipt]));
      when(repository.reportPeople).thenAnswer((_) async => _people);
      when(
        () => repository.sendReport(
          text: any(named: 'text'),
          tags: any(named: 'tags'),
          aboutUid: any(named: 'aboutUid'),
        ),
      ).thenAnswer((_) async => 'rep2');
      when(
        () => repository.addToReport(
          reportId: any(named: 'reportId'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) async {});
      when(() => repository.withdrawReport(any())).thenAnswer((_) async {});
    });

    ReportCubit build() =>
        ReportCubit(safetyRepository: repository, uid: 'ana');

    const ready = ReportState(status: ReportStatus.ready, people: _people);

    group('load', () {
      blocTest<ReportCubit, ReportState>(
        'follows the receipts and reads who "¿Con quién?" offers',
        build: build,
        act: (cubit) => cubit.load(),
        expect: () => [
          ReportState(receipts: [_receipt]),
          ReportState(
            status: ReportStatus.ready,
            people: _people,
            receipts: [_receipt],
          ),
        ],
      );

      blocTest<ReportCubit, ReportState>(
        'a failed read leaves only "Alguien de afuera"',
        setUp: () {
          when(() => repository.watchReceipts('ana'))
              .thenAnswer((_) => Stream.error(Exception('offline')));
          when(repository.reportPeople)
              .thenThrow(const SafetyFailure(SafetyFailureReason.other));
        },
        build: build,
        act: (cubit) => cubit.load(),
        expect: () => [const ReportState(status: ReportStatus.ready)],
        errors: () => hasLength(2),
      );

      test('emits nothing for people read after it closed', () async {
        final people = Completer<List<ReportPerson>>();
        when(repository.reportPeople).thenAnswer((_) => people.future);
        final cubit = build()..load();
        await cubit.close();

        people.complete(_people);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, equals(ReportStatus.loading));
      });
    });

    group('the form', () {
      blocTest<ReportCubit, ReportState>(
        'toggles tags, picks who and takes the words',
        build: build,
        seed: () => ready,
        act: (cubit) => cubit
          ..tagToggled(ReportTag.bothered)
          ..tagToggled(ReportTag.minor)
          ..tagToggled(ReportTag.bothered)
          ..aboutChosen('beto')
          ..textChanged('Me insistió'),
        expect: () => [
          ready.copyWith(tags: {ReportTag.bothered}),
          ready.copyWith(tags: {ReportTag.bothered, ReportTag.minor}),
          ready.copyWith(tags: {ReportTag.minor}),
          ready.copyWith(tags: {ReportTag.minor}, aboutUid: () => 'beto'),
          ready.copyWith(
            tags: {ReportTag.minor},
            aboutUid: () => 'beto',
            text: const ReportText.dirty('Me insistió'),
          ),
        ],
      );

      test('sends only with someone, a tag or words, not too long', () {
        expect(ready.canSend, isFalse);
        expect(ready.copyWith(aboutUid: () => '').canSend, isFalse);
        expect(
          ready.copyWith(aboutUid: () => '', tags: {ReportTag.other}).canSend,
          isTrue,
        );
        expect(
          ready
              .copyWith(
                aboutUid: () => '',
                text: const ReportText.dirty('  hola '),
              )
              .canSend,
          isTrue,
        );
        expect(
          ready
              .copyWith(
                aboutUid: () => '',
                text: ReportText.dirty('x' * (ReportText.maxLength + 1)),
              )
              .canSend,
          isFalse,
        );
        expect(
          ready
              .copyWith(
                aboutUid: () => '',
                tags: {ReportTag.other},
                send: ReportSendStatus.sending,
              )
              .canSend,
          isFalse,
        );
      });
    });

    group('submitted', () {
      final filled = ready.copyWith(
        aboutUid: () => 'beto',
        tags: {ReportTag.bothered},
        text: const ReportText.dirty(' Me insistió '),
      );

      blocTest<ReportCubit, ReportState>(
        'sends the trimmed words and empties the form',
        build: build,
        seed: () => filled,
        act: (cubit) => cubit.submitted(),
        expect: () => [
          filled.copyWith(send: ReportSendStatus.sending),
          ready.copyWith(send: ReportSendStatus.sent),
        ],
        verify: (_) => verify(
          () => repository.sendReport(
            text: 'Me insistió',
            tags: {ReportTag.bothered},
            aboutUid: 'beto',
          ),
        ).called(1),
      );

      blocTest<ReportCubit, ReportState>(
        'does nothing while it cannot send',
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.submitted(),
        expect: () => const <ReportState>[],
      );

      for (final (reason, status) in [
        (SafetyFailureReason.tooMany, ReportSendStatus.tooMany),
        (SafetyFailureReason.other, ReportSendStatus.failed),
      ]) {
        blocTest<ReportCubit, ReportState>(
          'says $status when it fails as $reason',
          setUp: () => when(
            () => repository.sendReport(
              text: any(named: 'text'),
              tags: any(named: 'tags'),
              aboutUid: any(named: 'aboutUid'),
            ),
          ).thenThrow(SafetyFailure(reason)),
          build: build,
          seed: () => filled,
          act: (cubit) => cubit.submitted(),
          expect: () => [
            filled.copyWith(send: ReportSendStatus.sending),
            filled.copyWith(send: status),
          ],
          errors: () => [isA<SafetyFailure>()],
        );
      }
    });

    group('a receipt', () {
      blocTest<ReportCubit, ReportState>(
        'Agregar algo adds the words and clears them',
        build: build,
        seed: () => ready,
        act: (cubit) async {
          cubit.additionChanged(' Y el jueves ');
          await cubit.addedTo('rep1');
        },
        expect: () => [
          ready.copyWith(addition: const ReportText.dirty(' Y el jueves ')),
          ready.copyWith(
            addition: const ReportText.dirty(' Y el jueves '),
            receiptId: () => 'rep1',
            receiptAction: () => ReceiptAction.adding,
          ),
          ready.copyWith(
            addition: const ReportText.dirty(' Y el jueves '),
            receiptId: () => 'rep1',
            receiptAction: () => ReceiptAction.added,
          ),
          ready.copyWith(
            receiptId: () => 'rep1',
            receiptAction: () => ReceiptAction.added,
          ),
        ],
        verify: (_) => verify(
          () => repository.addToReport(reportId: 'rep1', text: 'Y el jueves'),
        ).called(1),
      );

      blocTest<ReportCubit, ReportState>(
        'Agregar algo does nothing without words',
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.addedTo('rep1'),
        expect: () => const <ReportState>[],
      );

      blocTest<ReportCubit, ReportState>(
        'a failed addition keeps the words and says so',
        setUp: () => when(
          () => repository.addToReport(
            reportId: any(named: 'reportId'),
            text: any(named: 'text'),
          ),
        ).thenThrow(const SafetyFailure(SafetyFailureReason.gone)),
        build: build,
        seed: () => ready.copyWith(addition: const ReportText.dirty('más')),
        act: (cubit) => cubit.addedTo('rep1'),
        skip: 1,
        expect: () => [
          ready.copyWith(
            addition: const ReportText.dirty('más'),
            receiptId: () => 'rep1',
            receiptAction: () => ReceiptAction.failed,
          ),
        ],
        errors: () => [isA<SafetyFailure>()],
      );

      blocTest<ReportCubit, ReportState>(
        'Retirar withdraws it',
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.withdrawn('rep1'),
        expect: () => [
          ready.copyWith(
            receiptId: () => 'rep1',
            receiptAction: () => ReceiptAction.withdrawing,
          ),
          ready,
        ],
        verify: (_) =>
            verify(() => repository.withdrawReport('rep1')).called(1),
      );

      test('only open receipts can take more', () {
        final withdrawn = ReportReceipt(
          id: 'old',
          createdAt: DateTime.utc(2026, 10),
          withdrawn: true,
        );

        expect(
          ReportState(receipts: [_receipt, withdrawn]).openReceipts,
          equals([_receipt]),
        );
      });
    });
  });

  group(ReportText, () {
    test('may be empty, and counts the words without spaces', () {
      expect(const ReportText.dirty().isValid, isTrue);
      expect(const ReportText.dirty('  hola  ').words, equals('hola'));
      expect(
        ReportText.dirty('x' * (ReportText.maxLength + 1)).error,
        equals(ReportTextValidationError.tooLong),
      );
    });
  });
}
