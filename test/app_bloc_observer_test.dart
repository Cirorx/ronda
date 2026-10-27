import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app_bloc_observer.dart';

class _MockBloc extends Mock implements Bloc<Object?, Object?>;

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

    test('logs through dart:developer by default', () {
      expect(
        () => const AppBlocObserver().onChange(
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
