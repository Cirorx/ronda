import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/error_log/error_log.dart';

class _MockClientErrorLog extends Mock implements ClientErrorLog;

ClientError _error(
  String id, {
  String code = 'voice/uploadFailed',
  String screen = '/onboarding',
  String platform = 'web',
  String message = '',
  bool fatal = false,
  int hour = 20,
}) => ClientError(
  id: id,
  platform: platform,
  appVersion: '1.0.0',
  build: '3',
  flavor: 'production',
  screen: screen,
  step: 'voiceUpload',
  code: code,
  message: message,
  stack: '',
  fatal: fatal,
  at: DateTime.utc(2026, 10, 30, hour),
);

void main() {
  group(ErrorLogCubit, () {
    late ClientErrorLog log;
    late StreamController<List<ClientError>> errors;

    setUp(() {
      log = _MockClientErrorLog();
      errors = StreamController<List<ClientError>>.broadcast();
      addTearDown(errors.close);
      when(log.watchRecent).thenAnswer((_) => errors.stream);
    });

    test('starts loading', () {
      expect(
        ErrorLogCubit(clientErrorLog: log).state,
        equals(const ErrorLogState()),
      );
    });

    blocTest<ErrorLogCubit, ErrorLogState>(
      'shows the newest reports',
      build: () => ErrorLogCubit(clientErrorLog: log),
      act: (cubit) {
        cubit.subscribe();
        errors.add([_error('a')]);
      },
      expect: () => [
        const ErrorLogState(),
        ErrorLogState(status: ErrorLogStatus.ready, errors: [_error('a')]),
      ],
    );

    for (final (reason, status) in [
      (ClientErrorLogFailureReason.forbidden, ErrorLogStatus.forbidden),
      (ClientErrorLogFailureReason.other, ErrorLogStatus.failure),
    ]) {
      blocTest<ErrorLogCubit, ErrorLogState>(
        'shows $status when the read fails with ${reason.name}',
        build: () => ErrorLogCubit(clientErrorLog: log),
        act: (cubit) {
          cubit.subscribe();
          errors.addError(ClientErrorLogFailure(reason));
        },
        expect: () => [const ErrorLogState(), ErrorLogState(status: status)],
      );
    }

    blocTest<ErrorLogCubit, ErrorLogState>(
      'starts over when it subscribes again',
      build: () => ErrorLogCubit(clientErrorLog: log),
      seed: () => const ErrorLogState(status: ErrorLogStatus.failure),
      act: (cubit) => cubit.subscribe(),
      expect: () => [const ErrorLogState()],
    );

    blocTest<ErrorLogCubit, ErrorLogState>(
      'opens a group and keeps it open as reports land, then closes it',
      build: () => ErrorLogCubit(clientErrorLog: log),
      act: (cubit) async {
        cubit
          ..subscribe()
          ..groupOpened(ErrorGroup.keyOf('voice/uploadFailed', '/onboarding'));
        errors.add([_error('b'), _error('a')]);
        await Future<void>.delayed(Duration.zero);
        cubit.groupClosed();
      },
      expect: () => [
        const ErrorLogState(),
        const ErrorLogState(openGroup: 'voice/uploadFailed\n/onboarding\n'),
        ErrorLogState(
          status: ErrorLogStatus.ready,
          errors: [_error('b'), _error('a')],
          openGroup: 'voice/uploadFailed\n/onboarding\n',
        ),
        ErrorLogState(
          status: ErrorLogStatus.ready,
          errors: [_error('b'), _error('a')],
        ),
      ],
    );
  });

  group(ErrorLogState, () {
    test('groups by code and screen, the most recently seen first', () {
      final state = ErrorLogState(
        status: ErrorLogStatus.ready,
        errors: [
          _error('3', code: 'b', hour: 22),
          _error('2', platform: 'android', fatal: true, hour: 21),
          _error('1', code: 'b', screen: '/ronda'),
          _error('0', hour: 19),
        ],
        openGroup: ErrorGroup.keyOf('voice/uploadFailed', '/onboarding'),
      );

      final groups = state.groups;

      expect(groups.map((group) => (group.code, group.screen, group.count)), [
        ('b', '/onboarding', 1),
        ('voice/uploadFailed', '/onboarding', 2),
        ('b', '/ronda', 1),
      ]);
      expect(groups[1].latest.id, equals('2'));
      expect(groups[1].platforms, ['android', 'web']);
      expect(groups[1].fatal, isTrue);
      expect(groups.first.fatal, isFalse);
      expect(state.group, equals(groups[1]));
    });

    test('groups apart what said different things, titled by the message', () {
      final state = ErrorLogState(
        status: ErrorLogStatus.ready,
        errors: [
          _error('2', message: 'ReadPublishedSeatsFailure'),
          _error('1', message: 'SaveEligibleSeatIdsFailure'),
          _error('0', message: 'ReadPublishedSeatsFailure'),
        ],
      );

      final groups = state.groups;

      expect(groups.map((group) => (group.title, group.count)), [
        ('ReadPublishedSeatsFailure', 2),
        ('SaveEligibleSeatIdsFailure', 1),
      ]);
      expect(groups.first.code, equals('voice/uploadFailed'));
    });

    test('is titled by its code when it has no message', () {
      final group = ErrorLogState(errors: [_error('0')]).groups.single;

      expect(group.title, equals('voice/uploadFailed'));
    });

    test('copies every report of a group, split by a rule', () {
      final group = ErrorLogState(errors: [_error('1'), _error('0')])
          .groups
          .single;

      expect(group.reportText, contains('\n\n---\n\n'));
      expect(
        group.reportText,
        startsWith('screen: /onboarding\nstep: voiceUpload'),
      );
    });

    test('has no open group when it has no reports left', () {
      expect(const ErrorLogState(openGroup: 'gone\n/x\n').group, isNull);
    });
  });
}
