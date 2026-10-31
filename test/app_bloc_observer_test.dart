import 'package:bloc/bloc.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app_bloc_observer.dart';

class _MockBloc extends Mock implements Bloc<Object?, Object?>;

class _MockErrorReporter extends Mock implements ErrorReporter;

/// A state carrying personal data that must never reach the log.
final class const _MemberLoaded(final String phoneNumber) {
  @override
  String toString() => '_MemberLoaded($phoneNumber)';
}

final class const _MemberLoading();

final class const _PhoneNumberSubmitted(final String phoneNumber) {
  @override
  String toString() => '_PhoneNumberSubmitted($phoneNumber)';
}

final class const _LookupFailed(final String phoneNumber) implements Exception {
  @override
  String toString() => '_LookupFailed($phoneNumber)';
}

const _phoneNumber = '099123456';

void main() {
  group(AppBlocObserver, () {
    late Bloc<Object?, Object?> bloc;
    late List<String> messages;
    late List<StackTrace?> stackTraces;
    late AppBlocObserver observer;

    setUp(() {
      bloc = _MockBloc();
      messages = [];
      stackTraces = [];
      observer = AppBlocObserver(
        logger: (message, {stackTrace}) {
          messages.add(message);
          stackTraces.add(stackTrace);
        },
      );
    });

    group('onChange', () {
      test('logs the bloc and state type names only', () {
        observer.onChange(
          bloc,
          const Change<Object?>(
            currentState: _MemberLoading(),
            nextState: _MemberLoaded(_phoneNumber),
          ),
        );

        expect(
          messages,
          equals(['onChange($_MockBloc, $_MemberLoading -> $_MemberLoaded)']),
        );
        expect(messages.single, isNot(contains(_phoneNumber)));
      });
    });

    group('onChange of a fast bloc', () {
      test('logs one change a second at most', () {
        var now = DateTime(2026, 10, 30, 21);
        final lines = <String>[];
        final throttled = AppBlocObserver(
          logger: (message, {stackTrace}) => lines.add(message),
          now: () => now,
        );
        const change = Change<Object?>(
          currentState: _MemberLoading(),
          nextState: _MemberLoading(),
        );

        for (var n = 0; n < 25; n++) {
          throttled.onChange(bloc, change);
          now = now.add(const Duration(milliseconds: 40));
        }
        throttled.onChange(bloc, change);

        expect(lines, hasLength(2));
      });
    });

    group('onTransition', () {
      test('logs the bloc and event type names only', () {
        observer.onTransition(
          bloc,
          const Transition<Object?, Object?>(
            currentState: _MemberLoading(),
            event: _PhoneNumberSubmitted(_phoneNumber),
            nextState: _MemberLoaded(_phoneNumber),
          ),
        );

        expect(
          messages,
          equals(['onTransition($_MockBloc, $_PhoneNumberSubmitted)']),
        );
        expect(messages.single, isNot(contains(_phoneNumber)));
      });
    });

    group('onError', () {
      test('logs the error type name and the stack trace', () {
        final stackTrace = StackTrace.current;

        observer.onError(bloc, const _LookupFailed(_phoneNumber), stackTrace);

        expect(messages, equals(['onError($_MockBloc, $_LookupFailed)']));
        expect(messages.single, isNot(contains(_phoneNumber)));
        expect(stackTraces.single, same(stackTrace));
      });
    });

    group('with an error reporter', () {
      late ErrorReporter reporter;

      setUp(() {
        reporter = _MockErrorReporter();
        when(() => reporter.recordError(any(), any(), step: any(named: 'step')))
            .thenAnswer((_) async {});
      });

      test('sends a bloc error with the bloc type as the step', () {
        final stackTrace = StackTrace.current;
        const error = _LookupFailed(_phoneNumber);

        observer.reportingTo(reporter).onError(bloc, error, stackTrace);

        verify(
          () => reporter.recordError(error, stackTrace, step: '$_MockBloc'),
        ).called(1);
        expect(messages, hasLength(1));
      });

      test('logs nothing without a logger', () {
        AppBlocObserver(logger: null, errorReporter: reporter)
          ..onChange(
            bloc,
            const Change<Object?>(
              currentState: _MemberLoading(),
              nextState: _MemberLoaded(_phoneNumber),
            ),
          )
          ..onTransition(
            bloc,
            const Transition<Object?, Object?>(
              currentState: _MemberLoading(),
              event: _PhoneNumberSubmitted(_phoneNumber),
              nextState: _MemberLoaded(_phoneNumber),
            ),
          )
          ..onError(bloc, const _LookupFailed(_phoneNumber), StackTrace.empty);

        verify(
          () => reporter.recordError(any(), any(), step: any(named: 'step')),
        ).called(1);
      });
    });

    test('logs through dart:developer by default', () {
      expect(
        () => AppBlocObserver().onChange(
          bloc,
          const Change<Object?>(
            currentState: _MemberLoading(),
            nextState: _MemberLoaded(_phoneNumber),
          ),
        ),
        returnsNormally,
      );
    });
  });
}
