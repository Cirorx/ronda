import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/settings/settings.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

void main() {
  group(SettingsPage, () {
    late AppBloc appBloc;

    setUpAll(() => registerFallbackValue(const AppSignOutRequested()));

    setUp(() {
      appBloc = _MockAppBloc();
      whenListen(
        appBloc,
        const Stream<AppState>.empty(),
        initialState: const AppState(
          status: AppStatus.authenticated,
          user: User(id: 'demo-uid'),
        ),
      );
    });

    Future<void> pump(WidgetTester tester, {Locale locale = rioplatense}) =>
        tester.pumpApp(
          BlocProvider.value(value: appBloc, child: const SettingsPage()),
          locale: locale,
        );

    group('renders', () {
      testWidgets('its title and the four rows', (tester) async {
        await pump(tester);

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Ajustes'),
          ),
          findsOneWidget,
        );
        for (final row in [
          'Avisos',
          'Contar algo que pasó',
          'Tus datos',
          'Salir de esta cuenta',
        ]) {
          expect(find.widgetWithText(ListTile, row), findsOneWidget);
        }
      });

      testWidgets('in English', (tester) async {
        await pump(tester, locale: const Locale('en'));

        for (final row in [
          'Notifications',
          'Tell us something that happened',
          'Your data',
          'Sign out of this account',
        ]) {
          expect(find.widgetWithText(ListTile, row), findsOneWidget);
        }
      });

      testWidgets('each row under its Maestro identifier', (tester) async {
        await pump(tester);

        for (final identifier in [
          SettingsPage.notificationsIdentifier,
          SettingsPage.reportIdentifier,
          SettingsPage.dataIdentifier,
          SettingsPage.signOutIdentifier,
        ]) {
          expect(
            find.bySemanticsIdentifier(identifier),
            findsOneWidget,
            reason: identifier,
          );
        }
      });
    });

    group('signs out', () {
      Future<void> openSheet(WidgetTester tester) async {
        await pump(tester);
        await tester.tap(find.text('Salir de esta cuenta'));
        await tester.pumpAndSettle();
      }

      testWidgets('only after the confirmation', (tester) async {
        await openSheet(tester);

        expect(find.text('¿Salís de esta cuenta?'), findsOneWidget);
        expect(
          find.text(
            'Tu grupo y tus respuestas quedan guardados: si entrás con la '
            'misma cuenta, siguen ahí. Hasta que entres, a este teléfono no '
            'le llegan avisos.',
          ),
          findsOneWidget,
        );
        verifyNever(() => appBloc.add(any()));

        await tester.tap(find.widgetWithText(FilledButton, 'Salir'));
        await tester.pumpAndSettle();

        verify(() => appBloc.add(const AppSignOutRequested())).called(1);
        expect(find.text('¿Salís de esta cuenta?'), findsNothing);
      });

      testWidgets('not when the person changes their mind', (tester) async {
        await openSheet(tester);

        await tester.tap(find.text('Mejor no'));
        await tester.pumpAndSettle();

        expect(find.text('¿Salís de esta cuenta?'), findsNothing);
        verifyNever(() => appBloc.add(any()));
      });
    });
  });
}
