import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/cerca/cerca.dart';
import 'package:ronda/login/login.dart';
import 'package:ronda/my_ronda/my_ronda.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/settings/settings.dart';
import 'package:ronda/welcome/welcome.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

class _MockNeedsRepository extends Mock implements NeedsRepository;

class _MockProfileRepository extends Mock implements ProfileRepository;

class _MockRondaRepository extends Mock implements RondaRepository;

class _MockPushRepository extends Mock implements PushRepository;

class _MockOnboardingRepository extends Mock implements OnboardingRepository;

const _user = User(id: 'demo-uid');

final _profile = Profile(
  firstName: 'Marta',
  ageBand: AgeBand.sixties,
  barrio: Barrio.solymarNorte,
  pretexts: const {Pretext.mate},
  slots: {const Slot(SlotDay.thursday, SlotBand.afternoon)},
  brings: const {Bring.termo},
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  group(App, () {
    late AuthRepository authRepository;
    late NeedsRepository needsRepository;
    late ProfileRepository profileRepository;
    late RondaRepository rondaRepository;
    late PushRepository pushRepository;
    late StreamController<User> users;
    late StreamController<Profile?> profiles;

    setUpAll(() {
      registerFallbackValue(
        TermsAcceptance(version: '', acceptedAt: DateTime(2026)),
      );
    });

    setUp(() {
      authRepository = _MockAuthRepository();
      needsRepository = _MockNeedsRepository();
      profileRepository = _MockProfileRepository();
      rondaRepository = _MockRondaRepository();
      pushRepository = _MockPushRepository();
      when(pushRepository.permission)
          .thenAnswer((_) async => PushPermission.blocked);
      when(rondaRepository.watchLatestProposal)
          .thenAnswer((_) => Stream.value(null));
      users = StreamController<User>.broadcast();
      profiles = StreamController<Profile?>.broadcast();
      addTearDown(users.close);
      addTearDown(profiles.close);
      when(() => authRepository.currentUser).thenReturn(_user);
      when(() => authRepository.user).thenAnswer((_) => users.stream);
      when(() => profileRepository.watchProfile(any()))
          .thenAnswer((_) => profiles.stream);
      when(() => profileRepository.acceptTerms(any(), any()))
          .thenAnswer((_) async {});
    });

    Widget buildSubject() => App(
      authRepository: authRepository,
      needsRepository: needsRepository,
      onboardingRepository: _MockOnboardingRepository(),
      profileRepository: profileRepository,
      pushRepository: pushRepository,
      rondaRepository: rondaRepository,
    );

    /// Pumps the app with [_user] signed in and [profile] read, `_profile`
    /// by default.
    Future<void> pumpSignedIn(WidgetTester tester, {Profile? profile}) async {
      await tester.pumpWidget(buildSubject());
      users.add(_user);
      await tester.pump();
      profiles.add(profile ?? _profile);
      await tester.pumpAndSettle();
    }

    /// Pumps the app with nobody signed in.
    Future<void> pumpSignedOut(WidgetTester tester) async {
      when(() => authRepository.currentUser).thenReturn(User.empty);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('$MyRondaPage inside $AppShell on launch', (tester) async {
        await pumpSignedIn(tester);

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

        await pumpSignedIn(tester);

        final theme = Theme.of(tester.element(find.byType(MyRondaPage)));
        expect(theme.colorScheme, equals(AppTheme.light.colorScheme));
      });

      testWidgets('with $AppTheme.dark when the system is dark', (
        tester,
      ) async {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        await pumpSignedIn(tester);

        final theme = Theme.of(tester.element(find.byType(MyRondaPage)));
        expect(theme.colorScheme, equals(AppTheme.dark.colorScheme));
      });
    });

    group('provides', () {
      testWidgets('the repositories it was given to the tabs', (tester) async {
        await pumpSignedIn(tester);

        final context = tester.element(find.byType(MyRondaPage));
        expect(
          RepositoryProvider.of<NeedsRepository>(context),
          same(needsRepository),
        );
        expect(
          RepositoryProvider.of<AuthRepository>(context),
          same(authRepository),
        );
        expect(
          RepositoryProvider.of<PushRepository>(context),
          same(pushRepository),
        );
      });
    });

    group('localizes', () {
      testWidgets('the tabs in es-419 on an es_UY device', (tester) async {
        tester.platformDispatcher.localesTestValue = const [Locale('es', 'UY')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);

        await pumpSignedIn(tester);

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

        await pumpSignedIn(tester);

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
        await pumpSignedIn(tester);

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
        await pumpSignedIn(tester);

        await tester.tap(_tab('Nearby'));
        await tester.pumpAndSettle();
        await tester.tap(_tab('Nearby'));
        await tester.pumpAndSettle();

        expect(find.byType(CercaPage), findsOneWidget);
      });

      testWidgets('from / to $MyRondaPage', (tester) async {
        await pumpSignedIn(tester);
        await tester.tap(_tab('Settings'));
        await tester.pumpAndSettle();

        GoRouter.of(tester.element(find.byType(SettingsPage))).go('/');
        await tester.pumpAndSettle();

        expect(find.byType(MyRondaPage), findsOneWidget);
      });

      testWidgets('from an unknown location to $MyRondaPage', (tester) async {
        await pumpSignedIn(tester);
        await tester.tap(_tab('Settings'));
        await tester.pumpAndSettle();

        GoRouter.of(tester.element(find.byType(SettingsPage))).go('/nope');
        await tester.pumpAndSettle();

        expect(find.byType(MyRondaPage), findsOneWidget);
      });
    });

    group('guards sign-in', () {
      Finder buttonsDoor() =>
          find.bySemanticsIdentifier(WelcomePage.buttonsDoorIdentifier);

      testWidgets('by landing signed-out people on $WelcomePage', (
        tester,
      ) async {
        await pumpSignedOut(tester);

        expect(find.byType(WelcomePage), findsOneWidget);
        expect(find.byType(AppShell), findsNothing);
      });

      testWidgets('by keeping signed-out people on $WelcomePage from any '
          'location', (tester) async {
        await pumpSignedOut(tester);

        GoRouter.of(tester.element(find.byType(WelcomePage)))
            .go(SettingsPage.path);
        await tester.pumpAndSettle();

        expect(find.byType(WelcomePage), findsOneWidget);
        expect(find.byType(SettingsPage), findsNothing);
      });

      testWidgets('by opening $LoginPage only after a door is tapped', (
        tester,
      ) async {
        await pumpSignedOut(tester);

        GoRouter.of(tester.element(find.byType(WelcomePage)))
            .go(LoginPage.path);
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsNothing);

        await tester.tap(buttonsDoor());
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        verifyNever(() => profileRepository.acceptTerms(any(), any()));
      });

      testWidgets('by going back from $LoginPage to the doors', (tester) async {
        await pumpSignedOut(tester);
        await tester.tap(buttonsDoor());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(WelcomePage), findsOneWidget);
        expect(find.byType(LoginPage), findsNothing);
      });

      testWidgets('by opening the terms from $WelcomePage and coming back', (
        tester,
      ) async {
        await pumpSignedOut(tester);

        await tester.tap(
          find.bySemanticsIdentifier(WelcomePage.termsLinkIdentifier),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TermsPage), findsOneWidget);

        final done = find.bySemanticsIdentifier(TermsPage.doneIdentifier);
        await tester.scrollUntilVisible(done, 200);
        await tester.tap(done);
        await tester.pumpAndSettle();
        expect(find.byType(WelcomePage), findsOneWidget);
      });

      testWidgets('by recording the terms and opening $OnboardingPage once '
          'someone without a profile signs in', (tester) async {
        await pumpSignedOut(tester);
        await tester.tap(buttonsDoor());
        await tester.pumpAndSettle();

        users.add(_user);
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        profiles.add(null);
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingPage), findsOneWidget);
        verify(
          () => profileRepository.acceptTerms(
            'demo-uid',
            any(
              that: isA<TermsAcceptance>().having(
                (terms) => terms.version,
                'version',
                AppBloc.termsVersion,
              ),
            ),
          ),
        ).called(1);
      });

      testWidgets('by moving from $OnboardingPage to $MyRondaPage once the '
          'profile is saved', (tester) async {
        await tester.pumpWidget(buildSubject());
        users.add(_user);
        await tester.pump();
        profiles.add(null);
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingPage), findsOneWidget);

        profiles.add(_profile);
        await tester.pumpAndSettle();

        expect(find.byType(MyRondaPage), findsOneWidget);
        expect(find.byType(OnboardingPage), findsNothing);
      });

      testWidgets('by keeping people without a profile on $OnboardingPage', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        users.add(_user);
        await tester.pump();
        profiles.add(null);
        await tester.pumpAndSettle();

        GoRouter.of(tester.element(find.byType(OnboardingPage)))
            .go(SettingsPage.path);
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingPage), findsOneWidget);
      });

      testWidgets('by sending people with a profile away from welcome, '
          'sign-in and onboarding', (tester) async {
        await pumpSignedIn(tester);
        final router = GoRouter.of(tester.element(find.byType(MyRondaPage)));

        for (final path in [
          WelcomePage.path,
          LoginPage.path,
          TermsPage.path,
          OnboardingPage.path,
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(find.byType(MyRondaPage), findsOneWidget, reason: path);
        }
      });

      testWidgets('by opening $AdminPage for anyone signed in', (tester) async {
        await pumpSignedIn(tester);

        GoRouter.of(tester.element(find.byType(MyRondaPage)))
            .go(AdminPage.path);
        await tester.pumpAndSettle();

        expect(find.byType(AdminPage), findsOneWidget);
        expect(
          RepositoryProvider.of<RondaRepository>(
            tester.element(find.byType(AdminPage)),
          ),
          same(rondaRepository),
        );
      });

      testWidgets('by opening $AdminPage without a profile too', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        users.add(_user);
        await tester.pump();
        profiles.add(null);
        await tester.pumpAndSettle();

        GoRouter.of(tester.element(find.byType(OnboardingPage)))
            .go(AdminPage.path);
        await tester.pumpAndSettle();

        expect(find.byType(AdminPage), findsOneWidget);
      });

      testWidgets('by keeping signed-out people off $AdminPage', (
        tester,
      ) async {
        await pumpSignedOut(tester);

        GoRouter.of(tester.element(find.byType(WelcomePage)))
            .go(AdminPage.path);
        await tester.pumpAndSettle();

        expect(find.byType(WelcomePage), findsOneWidget);
      });

      testWidgets('by returning to $WelcomePage when the person signs out', (
        tester,
      ) async {
        await pumpSignedIn(tester);

        users.add(User.empty);
        await tester.pumpAndSettle();

        expect(find.byType(WelcomePage), findsOneWidget);
      });
    });
  });
}
