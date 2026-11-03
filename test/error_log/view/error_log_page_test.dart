import 'package:bloc_test/bloc_test.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/error_log/error_log.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockClientErrorLog extends Mock implements ClientErrorLog;

class _MockErrorLogCubit extends MockCubit<ErrorLogState>
    implements ErrorLogCubit;

ClientError _error(
  String id, {
  String code = 'voice/uploadFailed',
  String screen = '/onboarding',
  String platform = 'web',
  String step = 'voiceUpload',
  String message = '',
  String stack = '',
  bool fatal = false,
}) => ClientError(
  id: id,
  platform: platform,
  appVersion: '1.0.0',
  build: '3',
  flavor: 'production',
  screen: screen,
  step: step,
  code: code,
  message: message,
  stack: stack,
  fatal: fatal,
  at: DateTime(2026, 10, 30, 21, 15),
);

const _groupKey = 'voice/uploadFailed\n/onboarding\n';

void main() {
  group(ErrorLogPage, () {
    testWidgets('follows the newest reports', (tester) async {
      final log = _MockClientErrorLog();
      when(log.watchRecent).thenAnswer((_) => Stream.value(const []));

      await tester.pumpApp(
        RepositoryProvider<ClientErrorLog>.value(
          value: log,
          child: const ErrorLogPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No hubo errores en los últimos 30 días.'),
        findsOneWidget,
      );
      verify(log.watchRecent).called(1);
    });
  });

  group(ErrorLogView, () {
    late ErrorLogCubit cubit;

    setUp(() => cubit = _MockErrorLogCubit());

    Future<void> pump(WidgetTester tester, ErrorLogState state) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(value: cubit, child: const ErrorLogView()),
      );
    }

    final ready = ErrorLogState(
      status: ErrorLogStatus.ready,
      errors: [
        _error('2', platform: 'android', fatal: true),
        _error('1', code: 'firebase_auth/network-request-failed', screen: ''),
        _error('0'),
      ],
    );

    testWidgets('says what it is reading while it reads, read out', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const ErrorLogState());

      expect(find.byType(LoadingStatus), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Buscando los errores…')),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('tells someone who is not the admin', (tester) async {
      await pump(tester, const ErrorLogState(status: ErrorLogStatus.forbidden));

      expect(
        find.text('Esta pantalla es solo para quien arma las rondas.'),
        findsOneWidget,
      );
    });

    testWidgets('offers to try again when the read fails', (tester) async {
      await pump(tester, const ErrorLogState(status: ErrorLogStatus.failure));

      expect(
        find.text('No pudimos leer los errores. Probá de nuevo.'),
        findsOneWidget,
      );
      await tester.tap(find.byType(OutlinedButton));
      verify(cubit.subscribe).called(1);
    });

    testWidgets('lists each group with its count, last time and platforms', (
      tester,
    ) async {
      await pump(tester, ready);

      expect(find.text('voice/uploadFailed'), findsOneWidget);
      expect(
        find.textContaining('/onboarding · 2 veces · la última'),
        findsOneWidget,
      );
      expect(
        find.textContaining('android, web · 1.0.0 (3) · cortó la app'),
        findsOneWidget,
      );
      expect(find.textContaining('sin pantalla · una vez'), findsOneWidget);
    });

    testWidgets('opens a tapped group', (tester) async {
      await pump(tester, ready);

      await tester.tap(find.text('voice/uploadFailed'));

      verify(() => cubit.groupOpened(_groupKey)).called(1);
    });

    testWidgets("shows an open group's reports, newest first", (tester) async {
      await pump(
        tester,
        ErrorLogState(
          status: ErrorLogStatus.ready,
          errors: [
            _error(
              '1',
              stack: '#0 main (package:ronda/main.dart:1:2)',
              fatal: true,
            ),
            _error('0', step: ''),
          ],
          openGroup: _groupKey,
        ),
      );

      expect(find.text('Todos los errores'), findsOneWidget);
      expect(find.text('/onboarding · 2 veces'), findsOneWidget);
      expect(find.text('Se ven las 2 más nuevas.'), findsOneWidget);
      expect(find.text('Paso: voiceUpload'), findsOneWidget);
      expect(find.text('Stack'), findsOneWidget);
      expect(
        find.text('Sin mensaje: una falla que la app nombró.'),
        findsNWidgets(2),
      );
      expect(
        find.textContaining('1.0.0 (3) · production · cortó'),
        findsOneWidget,
      );
    });

    testWidgets('titles a group by its message and keeps the stack closed', (
      tester,
    ) async {
      final key = ErrorGroup.keyOf(
        'ReadPublishedSeatsFailure',
        '/onboarding',
        'ReadPublishedSeatsFailure',
      );
      await pump(
        tester,
        ErrorLogState(
          status: ErrorLogStatus.ready,
          errors: [
            _error(
              '0',
              code: 'ReadPublishedSeatsFailure',
              message: 'ReadPublishedSeatsFailure',
              stack: '#0 a (main.dart.js:1:2)',
            ),
          ],
          openGroup: key,
        ),
      );

      expect(find.text('ReadPublishedSeatsFailure'), findsWidgets);
      expect(find.text('#0 a (main.dart.js:1:2)'), findsNothing);

      await tester.tap(find.text('Stack'));
      await tester.pumpAndSettle();

      expect(find.text('#0 a (main.dart.js:1:2)'), findsOneWidget);
      expect(find.textContaining('flutter symbolize'), findsOneWidget);
    });

    group('copying', () {
      late List<String?> copied;

      setUp(() {
        copied = [];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copied.add((call.arguments as Map)['text'] as String?);
              }
              return null;
            });
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final open = ErrorLogState(
        status: ErrorLogStatus.ready,
        errors: [
          _error('1', message: 'Upload failed', stack: '#0 a'),
          _error('0', message: 'Upload failed', stack: '#0 b'),
        ],
        openGroup: ErrorGroup.keyOf(
          'voice/uploadFailed',
          '/onboarding',
          'Upload failed',
        ),
      );

      testWidgets('copies one report and says so', (tester) async {
        await pump(tester, open);

        await tester.tap(find.text('Copiar').first);
        await tester.pump();

        expect(copied.single, contains('code: voice/uploadFailed'));
        expect(copied.single, contains('message: Upload failed'));
        expect(copied.single, contains('#0 a'));
        expect(copied.single, isNot(contains('#0 b')));
        expect(find.text('Copiado'), findsOneWidget);
      });

      testWidgets('copies the whole group and says so', (tester) async {
        await pump(tester, open);

        await tester.tap(find.text('Copiar todos'));
        await tester.pump();

        expect(copied.single, allOf(contains('#0 a'), contains('#0 b')));
        expect(find.text('Copiado'), findsOneWidget);
      });
    });

    testWidgets('goes back to the groups from its button', (tester) async {
      await pump(tester, ready.copyWithOpen(_groupKey));

      await tester.tap(find.text('Todos los errores'));

      verify(cubit.groupClosed).called(1);
    });

    testWidgets("goes back to the groups on the system's back", (tester) async {
      await pump(tester, ready.copyWithOpen(_groupKey));

      await tester.binding.handlePopRoute();
      await tester.pump();

      verify(cubit.groupClosed).called(1);
    });
  });
}

extension on ErrorLogState {
  ErrorLogState copyWithOpen(String key) =>
      ErrorLogState(status: status, errors: errors, openGroup: key);
}
