import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/cerca/cerca.dart';
import 'package:ronda/login/login.dart';
import 'package:ronda/my_ronda/my_ronda.dart';
import 'package:ronda/settings/settings.dart';
import 'package:ronda_ui/ronda_ui.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

class _MockNeedsRepository extends Mock implements NeedsRepository;

const _user = User(id: 'demo-uid');

Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  group(App, () {
    late AuthRepository authRepository;
    late NeedsRepository needsRepository;
    late StreamController<User> users;

    setUp(() {
      authRepository = _MockAuthRepository();
      needsRepository = _MockNeedsRepository();
      users = StreamController<User>.broadcast();
      addTearDown(users.close);
      when(() => authRepository.currentUser).thenReturn(_user);
      when(() => authRepository.user).thenAnswer((_) => users.stream);
    });

    Widget buildSubject() =>
        App(authRepository: authRepository, needsRepository: needsRepository);

    group('renders', () {
      testWidgets('$MyRondaPage inside $AppShell on launch', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.byType(AppShell), findsOneWidget);
        expect(find.byType(MyRondaPage), findsOneWidget);
      });
    });

    group('themes', () {
      testWidgets('with $AppTheme.light when the system is light', (
        tester,
      ) async {
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final theme = Theme.of(tester.element(find.byType(MyRondaPage)));
        expect(theme.colorScheme, equals(AppTheme.light.colorScheme));
      });

      testWidgets('with $AppTheme.dark when the system is dark', (
        tester,
      ) async {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final theme = Theme.of(tester.element(find.byType(MyRondaPage)));
        expect(theme.colorScheme, equals(AppTheme.dark.colorScheme));
      });
    });

    group('provides', () {
      testWidgets('the repositories it was given to the tabs', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(MyRondaPage));
        expect(
          RepositoryProvider.of<NeedsRepository>(context),
          same(needsRepository),
        );
        expect(
          RepositoryProvider.of<AuthRepository>(context),
          same(authRepository),
        );
      });
    });

    group('localizes', () {
      testWidgets('the tabs in es-419 on an es_UY device', (tester) async {
        tester.platformDispatcher.localesTestValue = const [Locale('es', 'UY')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(
          Localizations.localeOf(tester.element(find.byType(MyRondaPage))),
          equals(const Locale('es', '419')),
        );
        expect(_tab('Mi ronda'), findsOneWidget);
        expect(_tab('Cerca'), findsOneWidget);
        expect(_tab('Ajustes'), findsOneWidget);
        expect(find.text('Estamos armando tu grupo'), findsOneWidget);
      });

      testWidgets('the tabs in English on an en_US device', (tester) async {
        tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(
          Localizations.localeOf(tester.element(find.byType(MyRondaPage))),
          equals(const Locale('en')),
        );
        expect(_tab('My ronda'), findsOneWidget);
        expect(_tab('Nearby'), findsOneWidget);
        expect(_tab('Settings'), findsOneWidget);
        expect(find.text("We're putting your group together"), findsOneWidget);
      });
    });

    group('navigates', () {
      testWidgets('to each tab when its destination is tapped', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(_tab('Nearby'));
        await tester.pumpAndSettle();
        expect(find.byType(CercaPage), findsOneWidget);
        expect(find.byType(MyRondaPage), findsNothing);

        await tester.tap(_tab('Settings'));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(find.byType(CercaPage), findsNothing);

        await tester.tap(_tab('My ronda'));
        await tester.pumpAndSettle();
        expect(find.byType(MyRondaPage), findsOneWidget);
        expect(find.byType(SettingsPage), findsNothing);
      });

      testWidgets('stays on the open tab when it is tapped again', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(_tab('Nearby'));
        await tester.pumpAndSettle();
        await tester.tap(_tab('Nearby'));
        await tester.pumpAndSettle();

        expect(find.byType(CercaPage), findsOneWidget);
      });

      testWidgets('from / to $MyRondaPage', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        await tester.tap(_tab('Settings'));
        await tester.pumpAndSettle();

        GoRouter.of(tester.element(find.byType(SettingsPage))).go('/');
        await tester.pumpAndSettle();

        expect(find.byType(MyRondaPage), findsOneWidget);
      });

      testWidgets('from an unknown location to $MyRondaPage', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        await tester.tap(_tab('Settings'));
        await tester.pumpAndSettle();

        GoRouter.of(tester.element(find.byType(SettingsPage))).go('/nope');
        await tester.pumpAndSettle();

        expect(find.byType(MyRondaPage), findsOneWidget);
      });
    });

    group('guards sign-in', () {
      testWidgets('by landing signed-out people on $LoginPage', (tester) async {
        when(() => authRepository.currentUser).thenReturn(User.empty);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(AppShell), findsNothing);
      });

      testWidgets('by moving to $MyRondaPage once the person signs in', (
        tester,
      ) async {
        when(() => authRepository.currentUser).thenReturn(User.empty);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        users.add(_user);
        await tester.pumpAndSettle();

        expect(find.byType(MyRondaPage), findsOneWidget);
        expect(find.byType(LoginPage), findsNothing);
      });

      testWidgets('by returning to $LoginPage when the person signs out', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        users.add(User.empty);
        await tester.pumpAndSettle();

        expect(find.byType(LoginPage), findsOneWidget);
      });

      testWidgets('by sending signed-in people away from $LoginPage', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        GoRouter.of(tester.element(find.byType(MyRondaPage)))
            .go(LoginPage.path);
        await tester.pumpAndSettle();

        expect(find.byType(MyRondaPage), findsOneWidget);
        expect(find.byType(LoginPage), findsNothing);
      });

      testWidgets('by keeping signed-out people on $LoginPage from any '
          'location', (tester) async {
        when(() => authRepository.currentUser).thenReturn(User.empty);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        GoRouter.of(tester.element(find.byType(LoginPage)))
            .go(SettingsPage.path);
        await tester.pumpAndSettle();

        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(SettingsPage), findsNothing);
      });
    });
  });
}
