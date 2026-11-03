import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:contact_repository/contact_repository.dart';
import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyer_repository/flyer_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/acta/acta.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda/agent_trace/agent_trace.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/attendance/attendance.dart';
import 'package:ronda/cerca/cerca.dart';
import 'package:ronda/donde_queda/donde_queda.dart';
import 'package:ronda/error_log/error_log.dart';
import 'package:ronda/login/login.dart';
import 'package:ronda/mate_flyer/mate_flyer.dart';
import 'package:ronda/my_data/my_data.dart';
import 'package:ronda/my_ronda/my_ronda.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/onboarding/view/steps/steps.dart';
import 'package:ronda/payoff/payoff.dart';
import 'package:ronda/phone_login/phone_login.dart';
import 'package:ronda/rain_move/rain_move.dart';
import 'package:ronda/ronda_setup/ronda_setup.dart';
import 'package:ronda/safety_queue/safety_queue.dart';
import 'package:ronda/settings/settings.dart';
import 'package:ronda/walkthrough/walkthrough.dart';
import 'package:ronda/welcome/welcome.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:safety_repository/safety_repository.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

import '../../helpers/helpers.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

class _MockContactRepository extends Mock implements ContactRepository;

class _MockCuadernoRepository extends Mock implements CuadernoRepository;
class _MockDondeQuedaRepository extends Mock implements DondeQuedaRepository;

class _MockNeedsRepository extends Mock implements NeedsRepository;

class _MockProfileRepository extends Mock implements ProfileRepository;

class _MockRondaRepository extends Mock implements RondaRepository;

class _MockPushRepository extends Mock implements PushRepository;

class _MockOnboardingRepository extends Mock implements OnboardingRepository;

class _MockFlyerRepository extends Mock implements FlyerRepository;

class _MockOrganiserRepository extends Mock implements OrganiserRepository;

class _MockSmallPlanRepository extends Mock implements SmallPlanRepository;

class _MockSafetyRepository extends Mock implements SafetyRepository;

class _MockErrorReporter extends Mock implements ErrorReporter;

class _MockClientErrorLog extends Mock implements ClientErrorLog;

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
    late ContactRepository contactRepository;
    late CuadernoRepository cuadernoRepository;
    late DondeQuedaRepository dondeQuedaRepository;
    late NeedsRepository needsRepository;
    late ProfileRepository profileRepository;
    late RondaRepository rondaRepository;
    late SmallPlanRepository smallPlanRepository;
    late SafetyRepository safetyRepository;
    late PushRepository pushRepository;
    late FlyerRepository flyerRepository;
    late OrganiserRepository organiserRepository;
    late OnboardingRepository onboardingRepository;
    late StreamController<User> users;
    late StreamController<Profile?> profiles;
    late StreamController<User> tokens;

    /// The answers held on this phone, as `ProfileRepository` holds them.
    Profile? held;

    /// Whether the signed-in account's token carries the admin claim.
    late bool adminClaim;

    setUpAll(() {
      registerFallbackValue(
        TermsAcceptance(version: '', acceptedAt: DateTime(2026)),
      );
      registerFallbackValue(_profile);
      registerFallbackValue(Needs.none);
      registerFallbackValue(AppLanguage.spanish);
      registerFallbackValue(<SeatFacts>[]);
    });

    setUp(() {
      authRepository = _MockAuthRepository();
      contactRepository = _MockContactRepository();
      dondeQuedaRepository = _MockDondeQuedaRepository();
      when(
        () => dondeQuedaRepository.watch(
          rondaId: any(named: 'rondaId'),
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) => Stream.value(const DondeQuedaWeek()));
      when(() => contactRepository.email).thenReturn('hola@example.com');
      cuadernoRepository = _MockCuadernoRepository();
      when(() => cuadernoRepository.changes)
          .thenAnswer((_) => const Stream<void>.empty());
      when(() => cuadernoRepository.read(any()))
          .thenAnswer((_) async => Cuaderno.empty);
      needsRepository = _MockNeedsRepository();
      profileRepository = _MockProfileRepository();
      rondaRepository = _MockRondaRepository();
      smallPlanRepository = _MockSmallPlanRepository();
      safetyRepository = _MockSafetyRepository();
      when(safetyRepository.watchUnreadCount)
          .thenAnswer((_) => const Stream.empty());
      when(() => safetyRepository.watchReceipts(any()))
          .thenAnswer((_) => const Stream.empty());
      when(safetyRepository.reportPeople).thenAnswer((_) async => const []);
      when(() => smallPlanRepository.current(any()))
          .thenAnswer((_) async => const SmallPlanNothing());
      pushRepository = _MockPushRepository();
      flyerRepository = _MockFlyerRepository();
      organiserRepository = _MockOrganiserRepository();
      onboardingRepository = _MockOnboardingRepository();
      when(organiserRepository.watchRuns).thenAnswer((_) => Stream.value([]));
      when(() => organiserRepository.watchActa(any()))
          .thenAnswer((_) => Stream.value(const Acta()));
      when(() => organiserRepository.watchMove(any(), any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => flyerRepository.canBlurFaces).thenReturn(true);
      when(flyerRepository.retrieveLostPhoto).thenAnswer((_) async => null);
      when(() => pushRepository.openedRolls)
          .thenAnswer((_) => const Stream.empty());
      when(pushRepository.launchedRoll).thenAnswer((_) async => null);
      when(pushRepository.permission)
          .thenAnswer((_) async => PushPermission.blocked);
      when(rondaRepository.watchLatestProposal)
          .thenAnswer((_) => Stream.value(null));
      when(() => rondaRepository.watchThisWeek(any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => rondaRepository.watchSeguimos(any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => rondaRepository.watchBenchOffers(any()))
          .thenAnswer((_) => Stream.value(const []));
      when(() => rondaRepository.watchWaiting(any()))
          .thenAnswer((_) => Stream.value(null));
      when(rondaRepository.watchSeguimosCounts)
          .thenAnswer((_) => Stream.value(const []));
      when(rondaRepository.pilotNumbers)
          .thenThrow(const ProposalsFailure(ProposalsFailureReason.forbidden));
      users = StreamController<User>.broadcast();
      profiles = StreamController<Profile?>.broadcast();
      addTearDown(users.close);
      addTearDown(profiles.close);
      when(() => authRepository.currentUser).thenReturn(_user);
      when(() => authRepository.user).thenAnswer((_) => users.stream);
      // A token comes with every sign-in and sign-out, and alone when it
      // is renewed.
      tokens = StreamController<User>.broadcast();
      addTearDown(tokens.close);
      when(() => authRepository.tokenChanges).thenAnswer((_) {
        // Listened to inside the test's own zone, so pumps deliver it.
        final mirror = users.stream.listen(tokens.add);
        addTearDown(mirror.cancel);
        return tokens.stream;
      });
      adminClaim = false;
      when(
        () => authRepository.hasAdminClaim(
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer((_) async => adminClaim);
      when(() => profileRepository.watchProfile(any()))
          .thenAnswer((_) => profiles.stream);
      when(() => profileRepository.acceptTerms(any(), any()))
          .thenAnswer((_) async {});
      held = null;
      when(() => profileRepository.holdTerms(any())).thenAnswer((_) async {});
      when(profileRepository.heldTerms).thenAnswer((_) async => null);
      when(profileRepository.clearHeldTerms).thenAnswer((_) async {});
      when(profileRepository.markWalkthroughSeen).thenAnswer((_) async {});
      when(() => profileRepository.holdAnswers(any())).thenAnswer(
        (invocation) async =>
            held = invocation.positionalArguments.single as Profile,
      );
      when(profileRepository.heldAnswers).thenAnswer((_) async => held);
      when(profileRepository.clearHeldAnswers).thenAnswer((_) async {
        held = null;
      });
      var needs = Needs.none;
      when(needsRepository.read).thenAnswer((_) async => needs);
      when(() => needsRepository.save(any())).thenAnswer(
        (invocation) async =>
            needs = invocation.positionalArguments.single as Needs,
      );
      when(() => needsRepository.eligibleSeatIds(any(), any()))
          .thenReturn(const []);
      when(profileRepository.publishedSeats).thenAnswer((_) async => const []);
      when(
        () => profileRepository.saveEligibleSeatIds(
          uid: any(named: 'uid'),
          seatIds: any(named: 'seatIds'),
        ),
      ).thenAnswer((_) async {});
      when(() => profileRepository.createProfile(any(), any()))
          .thenAnswer((_) async {});
      when(() => profileRepository.holdLanguage(any()))
          .thenAnswer((_) async {});
      when(() => rondaRepository.cerca(any())).thenAnswer(
        (_) async => const Cerca(
          barrioId: 'solymar-norte',
          byPretext: [CercaWaiting(pretextId: 'mate', count: 3)],
        ),
      );
    });

    Widget buildSubject({bool walkthroughSeen = true, AppLanguage? language}) =>
        App(
          authRepository: authRepository,
          contactRepository: contactRepository,
          cuadernoRepository: cuadernoRepository,
          dondeQuedaRepository: dondeQuedaRepository,
          flyerRepository: flyerRepository,
          needsRepository: needsRepository,
          onboardingRepository: onboardingRepository,
          organiserRepository: organiserRepository,
          profileRepository: profileRepository,
          pushRepository: pushRepository,
          rondaRepository: rondaRepository,
          safetyRepository: safetyRepository,
          smallPlanRepository: smallPlanRepository,
          walkthroughSeen: walkthroughSeen,
          language: language,
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

    /// Pumps the app with nobody signed in, on a phone that has shown
    /// "¿Cómo funciona?" unless [firstTime].
    Future<void> pumpSignedOut(
      WidgetTester tester, {
      bool firstTime = false,
    }) async {
      when(() => authRepository.currentUser).thenReturn(User.empty);
      await tester.pumpWidget(buildSubject(walkthroughSeen: !firstTime));
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
        expect(find.text('Todavía no tenés grupo'), findsOneWidget);
      });

      testWidgets('in the language picked on the phone, over the device', (
        tester,
      ) async {
        tester.platformDispatcher.localesTestValue = const [Locale('es', 'UY')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);

        await tester.pumpWidget(buildSubject(language: AppLanguage.english));
        users.add(_user);
        await tester.pump();
        profiles.add(_profile);
        await tester.pumpAndSettle();

        expect(_tab('My ronda'), findsOneWidget);
      });

      testWidgets('the welcome screen at once when its toggle is tapped', (
        tester,
      ) async {
        tester.platformDispatcher.localesTestValue = const [Locale('es', 'UY')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        await pumpSignedOut(tester);

        await tester.tap(find.bySemanticsIdentifier(LanguageToggle.identifier));
        await tester.pumpAndSettle();

        expect(find.text('Español'), findsOneWidget);
        verify(() => profileRepository.holdLanguage(AppLanguage.english))
            .called(1);
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
        expect(find.text("You don't have a group yet"), findsOneWidget);
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

      testWidgets('pressing a tab in on touch-down, without a haptic', (
        tester,
      ) async {
        await pumpSignedIn(tester);
        final haptics = recordHaptics(tester);
        double scaleOf() => tester
            .widget<AnimatedScale>(
              find
                  .ancestor(
                    of: find.byType(NavigationDestination).at(1),
                    matching: find.byType(AnimatedScale),
                  )
                  .first,
            )
            .scale;

        final gesture = await tester.startGesture(
          tester.getCenter(_tab('Nearby')),
        );
        await tester.pump();
        expect(scaleOf(), AppMotion.pressedScale);
        expect(find.byType(CercaPage), findsNothing);

        await gesture.up();
        await tester.pumpAndSettle();
        expect(scaleOf(), 1);
        expect(find.byType(CercaPage), findsOneWidget);
        expect(haptics, isEmpty);
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

      testWidgets('to each Ajustes screen and back', (tester) async {
        await pumpSignedIn(tester);
        await tester.tap(_tab('Settings'));
        await tester.pumpAndSettle();

        for (final (row, page) in [
          ('Notifications', NotificationsPage),
          ('Tell us something that happened', ReportPage),
          ('Your data', YourDataPage),
        ]) {
          await tester.tap(find.widgetWithText(ListTile, row));
          await tester.pumpAndSettle();
          expect(find.byType(page), findsOneWidget);
          expect(find.byType(AppShell), findsOneWidget);

          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(page), findsNothing);
          expect(find.byType(SettingsPage), findsOneWidget);
        }
      });

      testWidgets('to $MyDataPage from Ajustes and from Mi ronda', (
        tester,
      ) async {
        await pumpSignedIn(tester);
        await tester.tap(_tab('Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ListTile, 'My details'));
        await tester.pump();
        profiles.add(_profile);
        await tester.pumpAndSettle();
        expect(find.byType(MyDataPage), findsOneWidget);
        expect(find.byType(AppShell), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);

        await tester.tap(_tab('My ronda'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('My details'));
        await tester.pump();
        profiles.add(_profile);
        await tester.pumpAndSettle();
        expect(find.byType(MyDataPage), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(MyRondaPage), findsOneWidget);
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

      Finder voiceDoor() =>
          find.bySemanticsIdentifier(WelcomePage.voiceDoorIdentifier);

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

        await tester.tap(voiceDoor());
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        expect(
          find.text(
            'To listen to you, we need you to sign in with your '
            'account',
          ),
          findsOneWidget,
        );
        verifyNever(() => profileRepository.acceptTerms(any(), any()));
      });

      testWidgets('by opening $PhoneLoginPage under $LoginPage', (
        tester,
      ) async {
        await pumpSignedOut(tester);

        await tester.tap(voiceDoor());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sign in with my mobile number'));
        await tester.pumpAndSettle();

        expect(find.byType(PhoneLoginPage), findsOneWidget);
        expect(
          GoRouter.of(tester.element(find.byType(PhoneLoginPage)))
              .state
              .matchedLocation,
          equals(LoginPage.phonePath),
        );
      });

      testWidgets('by keeping signed-out people off the questions and the '
          'payoff until a door is tapped', (tester) async {
        await pumpSignedOut(tester);
        final router = GoRouter.of(tester.element(find.byType(WelcomePage)));

        for (final path in [
          OnboardingPage.path,
          PayoffPage.path,
          PayoffPage.signInPath,
          PayoffPage.phoneSignInPath,
          LoginPage.phonePath,
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(find.byType(WelcomePage), findsOneWidget, reason: path);
        }
      });

      testWidgets('by opening the questions, signed out, after the buttons '
          'door', (tester) async {
        await pumpSignedOut(tester);

        await tester.tap(buttonsDoor());
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingPage), findsOneWidget);
        expect(find.byType(PretextsStep), findsOneWidget);
        expect(find.byType(LoginPage), findsNothing);
        verify(() => profileRepository.holdTerms(any())).called(1);
        verifyNever(() => profileRepository.acceptTerms(any(), any()));
      });

      testWidgets('by asking the questions, then the payoff, then sign-in '
          'once, then saving the profile and the terms', (tester) async {
        Future<void> tapId(String identifier) async {
          final target = find.bySemanticsIdentifier(identifier);
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        await pumpSignedOut(tester);
        await tester.tap(buttonsDoor());
        await tester.pumpAndSettle();

        for (final identifier in [
          'onboarding.pretexts.mate',
          'onboarding.next',
          'onboarding.brings.pan',
          'onboarding.next',
          'onboarding.slots.6.1',
          'onboarding.next',
          'onboarding.barrio.solymarNorte',
          'onboarding.next',
          'onboarding.ageBand.sixties',
          'onboarding.next',
          'onboarding.needs.walkALot',
          'onboarding.next',
        ]) {
          await tapId(identifier);
        }
        await tester.enterText(find.byType(TextField), 'Marta');
        await tester.pumpAndSettle();
        await tapId('onboarding.next');
        await tapId(ReviewStep.saveIdentifier);

        // Held on the phone, nothing written: the payoff, signed out.
        final answers = Profile(
          firstName: 'Marta',
          ageBand: AgeBand.sixties,
          barrio: Barrio.solymarNorte,
          pretexts: const {Pretext.mate},
          slots: {const Slot(SlotDay.sunday, SlotBand.afternoon)},
          brings: const {Bring.pan},
        );
        expect(held, equals(answers));
        expect(find.byType(PayoffPage), findsOneWidget);
        expect(
          find.text('3 neighbours near you signed up for mate.'),
          findsOneWidget,
        );
        verify(() => rondaRepository.cerca('solymar-norte')).called(1);
        verifyNever(profileRepository.publishedSeats);
        verifyNever(() => profileRepository.createProfile(any(), any()));

        await tapId(PayoffView.continueIdentifier);
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.text('Keep your place'), findsOneWidget);

        // Phone sign-in sits under the payoff's sign-in.
        await tester.tap(find.text('Sign in with my mobile number'));
        await tester.pumpAndSettle();
        expect(find.byType(PhoneLoginPage), findsOneWidget);
        expect(
          GoRouter.of(tester.element(find.byType(PhoneLoginPage)))
              .state
              .matchedLocation,
          equals(PayoffPage.phoneSignInPath),
        );

        // Signed in: the terms, then the held answers saved straight away.
        users.add(_user);
        await tester.pumpAndSettle();
        profiles.add(null);
        await tester.pumpAndSettle();
        verifyInOrder([
          () => profileRepository.acceptTerms('demo-uid', any()),
          () => needsRepository.save(const Needs({Need.walkALot})),
          () => profileRepository.saveEligibleSeatIds(
            uid: 'demo-uid',
            seatIds: const [],
          ),
          () => profileRepository.createProfile('demo-uid', answers),
        ]);

        profiles.add(answers);
        await tester.pumpAndSettle();
        expect(find.byType(MyRondaPage), findsOneWidget);
        expect(held, isNull);
      });

      testWidgets('by keeping the answers when the person backs out of '
          'sign-in', (tester) async {
        held = _profile;
        await pumpSignedOut(tester);
        await tester.tap(buttonsDoor());
        await tester.pumpAndSettle();
        expect(find.byType(ReviewStep), findsOneWidget);

        await tester.tap(find.bySemanticsIdentifier(ReviewStep.saveIdentifier));
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsIdentifier(PayoffView.continueIdentifier),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(PayoffPage), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(ReviewStep), findsOneWidget);
        expect(find.text('Marta'), findsOneWidget);
        expect(held, equals(_profile));
      });

      group('the first time on this phone', () {
        GoRouter routerOf(WidgetTester tester, Type page) =>
            GoRouter.of(tester.element(find.byType(page)));

        testWidgets('by showing $WalkthroughPage before the doors', (
          tester,
        ) async {
          await pumpSignedOut(tester, firstTime: true);

          expect(find.byType(WalkthroughPage), findsOneWidget);
          expect(find.byType(WelcomePage), findsNothing);
          verifyNever(profileRepository.markWalkthroughSeen);

          await tester.tap(
            find.bySemanticsIdentifier(WalkthroughPage.skipIdentifier),
          );
          await tester.pumpAndSettle();
          expect(find.byType(WelcomePage), findsOneWidget);
          verify(profileRepository.markWalkthroughSeen).called(1);
        });

        testWidgets('by switching its language in place, on the same card', (
          tester,
        ) async {
          tester.platformDispatcher.localesTestValue = const [
            Locale('es', 'UY'),
          ];
          addTearDown(tester.platformDispatcher.clearLocalesTestValue);
          await pumpSignedOut(tester, firstTime: true);
          await tester.tap(
            find.bySemanticsIdentifier(WalkthroughPage.nextIdentifier),
          );
          await tester.pumpAndSettle();

          await tester.tap(
            find.bySemanticsIdentifier(LanguageToggle.identifier),
          );
          await tester.pumpAndSettle();

          expect(find.byType(WalkthroughPage), findsOneWidget);
          expect(find.text("One message a week, that's it"), findsOneWidget);
          verify(() => profileRepository.holdLanguage(AppLanguage.english))
              .called(1);
        });

        testWidgets('by showing it only once', (tester) async {
          await pumpSignedOut(tester, firstTime: true);
          await tester.tap(
            find.bySemanticsIdentifier(WalkthroughPage.skipIdentifier),
          );
          await tester.pumpAndSettle();
          // The app's entrance again.
          routerOf(tester, WelcomePage).go(MyRondaPage.path);
          await tester.pumpAndSettle();

          expect(find.byType(WelcomePage), findsOneWidget);
          expect(find.byType(WalkthroughPage), findsNothing);
        });

        for (final (link, landing) in [
          (WelcomePage.path, WelcomePage.path),
          (ActaPage.location('r1'), WelcomePage.path),
          (
            '${WelcomePage.path}?$returnToParameter=${AdminPage.path}',
            '${WelcomePage.path}?$returnToParameter=${AdminPage.path}',
          ),
          (
            AdminPage.path,
            '${WelcomePage.path}?$returnToParameter=${AdminPage.path}',
          ),
        ]) {
          testWidgets('but not when the app opens on $link', (tester) async {
            tester.binding.platformDispatcher.defaultRouteNameTestValue = link;
            addTearDown(
              tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
            );
            await pumpSignedOut(tester, firstTime: true);

            expect(find.byType(WalkthroughPage), findsNothing);
            expect(find.byType(WelcomePage), findsOneWidget);
            expect(
              routerOf(
                tester,
                WelcomePage,
              ).routeInformationProvider.value.uri.toString(),
              equals(landing),
            );
            verifyNever(profileRepository.markWalkthroughSeen);
          });
        }

        testWidgets('by sending signed-in people from it to $MyRondaPage', (
          tester,
        ) async {
          await pumpSignedIn(tester);
          GoRouter.of(tester.element(find.byType(MyRondaPage)))
              .go(WalkthroughPage.path);
          await tester.pumpAndSettle();

          expect(find.byType(WalkthroughPage), findsNothing);
          expect(find.byType(MyRondaPage), findsOneWidget);
        });
      });

      testWidgets('by opening $WalkthroughPage again from $WelcomePage and '
          'coming back', (tester) async {
        await pumpSignedOut(tester);

        await tester.tap(
          find.bySemanticsIdentifier(WelcomePage.howItWorksIdentifier),
        );
        await tester.pumpAndSettle();
        expect(find.byType(WalkthroughPage), findsOneWidget);

        for (var i = 0; i < WalkthroughPage.cardCount; i++) {
          await tester.tap(
            find.bySemanticsIdentifier(WalkthroughPage.nextIdentifier),
          );
          await tester.pumpAndSettle();
        }
        expect(find.byType(WalkthroughPage), findsNothing);
        expect(find.byType(WelcomePage), findsOneWidget);
      });

      testWidgets('by going back from the first question to the doors, '
          'answering again from the start', (tester) async {
        await pumpSignedOut(tester);
        await tester.tap(buttonsDoor());
        await tester.pumpAndSettle();
        expect(find.byType(PretextsStep), findsOneWidget);

        await tester.tap(
          find.bySemanticsIdentifier(OnboardingStepLayout.backIdentifier),
        );
        await tester.pumpAndSettle();
        expect(find.byType(WelcomePage), findsOneWidget);

        await tester.tap(buttonsDoor());
        await tester.pumpAndSettle();
        expect(find.byType(PretextsStep), findsOneWidget);
      });

      testWidgets('by going back from $LoginPage to the doors', (tester) async {
        await pumpSignedOut(tester);
        await tester.tap(voiceDoor());
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

        // The test window is short: the doors and the link scroll into view.
        final terms = find.bySemanticsIdentifier(
          WelcomePage.termsLinkIdentifier,
        );
        await tester.ensureVisible(terms);
        await tester.tap(terms);
        await tester.pumpAndSettle();
        expect(find.byType(TermsPage), findsOneWidget);

        final done = find.bySemanticsIdentifier(TermsPage.doneIdentifier);
        await tester.scrollUntilVisible(done, 200);
        await tester.ensureVisible(done);
        await tester.pumpAndSettle();
        await tester.tap(done);
        await tester.pumpAndSettle();
        expect(find.byType(WelcomePage), findsOneWidget);
      });

      testWidgets('by recording the terms and opening $OnboardingPage once '
          'someone without a profile signs in', (tester) async {
        when(() => onboardingRepository.startVoiceNote(any()))
            .thenAnswer((_) async {});
        when(onboardingRepository.discardVoiceNote).thenAnswer((_) async {});
        await pumpSignedOut(tester);
        await tester.tap(voiceDoor());
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
          PayoffPage.path,
          PayoffPage.signInPath,
          LoginPage.phonePath,
          PayoffPage.phoneSignInPath,
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(find.byType(MyRondaPage), findsOneWidget, reason: path);
        }
      });

      testWidgets('by opening $AdminPage for the admin', (tester) async {
        adminClaim = true;
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
        verify(() => authRepository.hasAdminClaim(forceRefresh: true))
            .called(1);
      });

      testWidgets('by counting the unread reports for the admin only', (
        tester,
      ) async {
        when(safetyRepository.watchUnreadCount)
            .thenAnswer((_) => Stream.value(2));
        adminClaim = true;
        await pumpSignedIn(tester);

        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        verify(safetyRepository.watchUnreadCount).called(1);
      });

      testWidgets('by asking a member for no unread count', (tester) async {
        await pumpSignedIn(tester);

        verifyNever(safetyRepository.watchUnreadCount);
      });

      testWidgets('by showing the admin an Admin tab that opens $AdminPage', (
        tester,
      ) async {
        tester.platformDispatcher.localesTestValue = const [Locale('es', 'UY')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        adminClaim = true;
        await pumpSignedIn(tester);

        await tester.tap(_tab('Admin'));
        await tester.pumpAndSettle();

        expect(find.byType(AdminPage), findsOneWidget);
        expect(find.byType(AppShell), findsOneWidget);

        await tester.tap(find.byType(AgentTraceLink));
        await tester.pumpAndSettle();

        expect(find.byType(AgentTracePage), findsOneWidget);
        expect(find.byType(AppShell), findsOneWidget);
        expect(_tab('Admin'), findsOneWidget);
      });

      testWidgets('by opening the reports from the admin screen', (
        tester,
      ) async {
        when(safetyRepository.watchQueue)
            .thenAnswer((_) => Stream.value(const SafetyQueue()));
        adminClaim = true;
        await pumpSignedIn(tester);
        await tester.tap(_tab('Admin'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(SafetyQueueLink));
        await tester.pumpAndSettle();

        expect(find.byType(SafetyQueuePage), findsOneWidget);
        expect(_tab('Admin'), findsOneWidget);
      });

      testWidgets('by showing a member no Admin tab', (tester) async {
        await pumpSignedIn(tester);

        expect(_tab('My ronda'), findsOneWidget);
        expect(_tab('Admin'), findsNothing);
      });

      for (final (name, location) in [
        ('', AdminPage.path),
        (' trace', AgentTracePage.path),
        (' setup', RondaSetupPage.path),
        (' errors', ErrorLogPage.path),
        (' reports', SafetyQueuePage.path),
        (' roll', AttendancePage.location('ronda-1', '2026-W45', admin: true)),
      ]) {
        testWidgets('by sending a member who opens the admin$name screen '
            'to $MyRondaPage, reading nothing for it', (tester) async {
          when(rondaRepository.rondaSetups).thenAnswer((_) async => const []);
          when(() => rondaRepository.watchRoll(any(), any()))
              .thenAnswer((_) => Stream.value(null));
          await pumpSignedIn(tester);

          GoRouter.of(tester.element(find.byType(MyRondaPage))).go(location);
          await tester.pumpAndSettle();

          expect(find.byType(MyRondaPage), findsOneWidget);
          expect(find.byType(AdminPage), findsNothing);
          expect(find.byType(AdminGate), findsNothing);
          verifyNever(rondaRepository.watchLatestProposal);
          verifyNever(rondaRepository.watchSeguimosCounts);
          verifyNever(rondaRepository.pilotNumbers);
          verifyNever(rondaRepository.rondaSetups);
          verifyNever(organiserRepository.watchRuns);
          verifyNever(() => rondaRepository.watchRoll(any(), any()));
          verifyNever(safetyRepository.watchQueue);
        });
      }

      testWidgets('by sending a member without a profile who opens '
          '$AdminPage to onboarding', (tester) async {
        await tester.pumpWidget(buildSubject());
        users.add(_user);
        await tester.pump();
        profiles.add(null);
        await tester.pumpAndSettle();

        GoRouter.of(tester.element(find.byType(OnboardingPage)))
            .go(AdminPage.path);
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingPage), findsOneWidget);
        expect(find.byType(AdminPage), findsNothing);
        verifyNever(rondaRepository.watchLatestProposal);
      });

      testWidgets('by waiting on $AdminPage while the claim is read', (
        tester,
      ) async {
        final claim = Completer<bool>();
        when(
          () => authRepository.hasAdminClaim(
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) => claim.future);
        await tester.pumpWidget(buildSubject());
        users.add(_user);
        await tester.pump();
        profiles.add(_profile);
        await tester.pump();
        GoRouter.of(tester.element(find.byType(MyRondaPage)))
            .go(AdminPage.path);
        await tester.pump();
        await tester.pump();

        expect(find.byType(AdminGate), findsOneWidget);
        expect(find.byType(AdminPage), findsNothing);
        verifyNever(rondaRepository.watchLatestProposal);

        claim.complete(true);
        await tester.pumpAndSettle();

        expect(find.byType(AdminPage), findsOneWidget);
      });

      testWidgets('by hiding the Admin tab and leaving $AdminPage when a '
          'renewed token loses the claim', (tester) async {
        tester.platformDispatcher.localesTestValue = const [Locale('en')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        adminClaim = true;
        await pumpSignedIn(tester);
        await tester.tap(_tab('Admin'));
        await tester.pumpAndSettle();
        expect(find.byType(AdminPage), findsOneWidget);

        adminClaim = false;
        tokens.add(_user);
        await tester.pumpAndSettle();

        expect(find.byType(MyRondaPage), findsOneWidget);
        expect(find.byType(AdminPage), findsNothing);
        expect(_tab('Admin'), findsNothing);
        verify(() => authRepository.hasAdminClaim(forceRefresh: false))
            .called(1);
      });

      testWidgets('by opening $AdminPage without a profile too', (
        tester,
      ) async {
        adminClaim = true;
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

      testWidgets('by opening the $MateFlyerPage of a ronda', (tester) async {
        await pumpSignedIn(tester);

        GoRouter.of(tester.element(find.byType(MyRondaPage)))
            .go(MateFlyerPage.location('ronda-1'));
        await tester.pumpAndSettle();

        expect(
          tester.widget<MateFlyerPage>(find.byType(MateFlyerPage)).rondaId,
          equals('ronda-1'),
        );
        expect(
          RepositoryProvider.of<FlyerRepository>(
            tester.element(find.byType(MateFlyerPage)),
          ),
          same(flyerRepository),
        );
      });

      for (final (name, location, type) in [
        ('photo', DondeQuedaPhotoPage.location('ronda-1'), DondeQuedaPhotoPage),
        ('guess', DondeQuedaGuessPage.location('ronda-1'), DondeQuedaGuessPage),
      ]) {
        testWidgets('by opening the ¿Dónde queda? $name screen of a '
            'ronda', (tester) async {
          await pumpSignedIn(tester);

          GoRouter.of(tester.element(find.byType(MyRondaPage))).go(location);
          await tester.pumpAndSettle();

          expect(find.byType(type), findsOneWidget);
        });
      }

      testWidgets('by opening the trace under $AdminPage without a profile', (
        tester,
      ) async {
        adminClaim = true;
        await tester.pumpWidget(buildSubject());
        users.add(_user);
        await tester.pump();
        profiles.add(null);
        await tester.pumpAndSettle();

        GoRouter.of(tester.element(find.byType(OnboardingPage)))
            .go(AgentTracePage.path);
        await tester.pumpAndSettle();

        expect(find.byType(AgentTracePage), findsOneWidget);
        verify(organiserRepository.watchRuns).called(1);
      });

      testWidgets('by opening the errors under $AdminPage, telling the '
          'reporter each route pattern', (tester) async {
        adminClaim = true;
        final reporter = _MockErrorReporter();
        final log = _MockClientErrorLog();
        when(log.watchRecent).thenAnswer((_) => Stream.value(const []));
        await tester.pumpWidget(
          MultiRepositoryProvider(
            providers: [
              RepositoryProvider<ErrorReporter>.value(value: reporter),
              RepositoryProvider<ClientErrorLog>.value(value: log),
            ],
            child: buildSubject(),
          ),
        );
        users.add(_user);
        await tester.pump();
        profiles.add(_profile);
        await tester.pumpAndSettle();

        GoRouter.of(tester.element(find.byType(MyRondaPage)))
            .go(ActaPage.location('ronda-1'));
        await tester.pumpAndSettle();
        GoRouter.of(tester.element(find.byType(ActaPage)))
            .go(ErrorLogPage.path);
        await tester.pumpAndSettle();

        expect(find.byType(ErrorLogPage), findsOneWidget);
        verify(() => reporter.setScreen(MyRondaPage.path))
            .called(greaterThan(0));
        verify(() => reporter.setScreen(ActaPage.path)).called(greaterThan(0));
        verify(() => reporter.setScreen(ErrorLogPage.path))
            .called(greaterThan(0));
        verifyNever(() => reporter.setScreen('/acta/ronda-1'));
      });

      testWidgets('by opening the $ActaPage of a ronda', (tester) async {
        await pumpSignedIn(tester);

        GoRouter.of(tester.element(find.byType(MyRondaPage)))
            .go(ActaPage.location('ronda-1'));
        await tester.pumpAndSettle();

        expect(
          tester.widget<ActaPage>(find.byType(ActaPage)).rondaId,
          equals('ronda-1'),
        );
        verify(() => organiserRepository.watchActa('ronda-1')).called(1);
      });

      testWidgets("by opening the host's $RainMovePage from its link", (
        tester,
      ) async {
        await pumpSignedIn(tester);

        GoRouter.of(tester.element(find.byType(MyRondaPage)))
            .go(RainMovePage.location('ronda-1', '2026-W45'));
        await tester.pumpAndSettle();

        final page = tester.widget<RainMovePage>(find.byType(RainMovePage));
        expect((page.rondaId, page.week), ('ronda-1', '2026-W45'));
        verify(() => organiserRepository.watchMove('ronda-1', '2026-W45'))
            .called(1);
      });

      testWidgets("by opening the host's $AttendancePage from its link", (
        tester,
      ) async {
        when(() => rondaRepository.watchRoll(any(), any()))
            .thenAnswer((_) => Stream.value(null));
        await pumpSignedIn(tester);

        GoRouter.of(tester.element(find.byType(MyRondaPage)))
            .go(AttendancePage.location('ronda-1', '2026-W45'));
        await tester.pumpAndSettle();

        final page = tester.widget<AttendancePage>(find.byType(AttendancePage));
        expect((page.rondaId, page.week), ('ronda-1', '2026-W45'));
        verify(() => rondaRepository.watchRoll('ronda-1', '2026-W45'))
            .called(1);
      });

      testWidgets('by opening the roll when "¿Quién vino hoy?" is tapped', (
        tester,
      ) async {
        final rolls = StreamController<OpenedRoll>();
        addTearDown(() => unawaited(rolls.close()));
        when(() => pushRepository.openedRolls).thenAnswer((_) => rolls.stream);
        when(() => rondaRepository.watchRoll(any(), any()))
            .thenAnswer((_) => Stream.value(null));
        await pumpSignedIn(tester);

        rolls.add(const OpenedRoll(rondaId: 'ronda-1', week: '2026-W45'));
        await tester.pumpAndSettle();

        final page = tester.widget<AttendancePage>(find.byType(AttendancePage));
        expect((page.rondaId, page.week), ('ronda-1', '2026-W45'));
      });

      testWidgets('by opening the roll when its tap started the app', (
        tester,
      ) async {
        when(pushRepository.launchedRoll).thenAnswer(
          (_) async => const OpenedRoll(rondaId: 'ronda-1', week: '2026-W45'),
        );
        when(() => rondaRepository.watchRoll(any(), any()))
            .thenAnswer((_) => Stream.value(null));
        await pumpSignedIn(tester);

        expect(find.byType(AttendancePage), findsOneWidget);
      });

      testWidgets('by opening the setup and the roll under $AdminPage '
          'without a profile', (tester) async {
        adminClaim = true;
        when(rondaRepository.rondaSetups).thenAnswer((_) async => const []);
        when(() => rondaRepository.watchRoll(any(), any()))
            .thenAnswer((_) => Stream.value(null));
        await tester.pumpWidget(buildSubject());
        users.add(_user);
        await tester.pump();
        profiles.add(null);
        await tester.pumpAndSettle();
        GoRouter.of(tester.element(find.byType(OnboardingPage)))
            .go(RondaSetupPage.path);
        await tester.pumpAndSettle();
        expect(find.byType(RondaSetupPage), findsOneWidget);
        verify(rondaRepository.rondaSetups).called(1);

        GoRouter.of(tester.element(find.byType(RondaSetupPage)))
            .go(AttendancePage.location('ronda-1', '2026-W45', admin: true));
        await tester.pumpAndSettle();
        final page = tester.widget<AttendancePage>(find.byType(AttendancePage));
        expect((page.rondaId, page.week), ('ronda-1', '2026-W45'));
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

      group('from $AdminPage', () {
        /// Signs in from [location] through the buttons door, with [profile]
        /// read once signed in.
        Future<void> signInFrom(
          WidgetTester tester,
          String location, {
          Profile? profile,
          bool admin = true,
        }) async {
          adminClaim = admin;
          await pumpSignedOut(tester);
          GoRouter.of(tester.element(find.byType(WelcomePage))).go(location);
          await tester.pumpAndSettle();
          await tester.tap(buttonsDoor());
          await tester.pumpAndSettle();
          expect(find.byType(LoginPage), findsOneWidget);

          users.add(_user);
          await tester.pumpAndSettle();
          profiles.add(profile);
          await tester.pumpAndSettle();
        }

        String currentLocation(WidgetTester tester) =>
            GoRouter.of(tester.element(find.byType(Navigator).first)).state.uri
                .toString();

        testWidgets('by saying so on the way to $WelcomePage', (tester) async {
          await pumpSignedOut(tester);

          GoRouter.of(tester.element(find.byType(WelcomePage)))
              .go(AdminPage.path);
          await tester.pumpAndSettle();
          await tester.tap(buttonsDoor());
          await tester.pumpAndSettle();

          expect(
            currentLocation(tester),
            equals('${LoginPage.path}?$returnToParameter=${AdminPage.path}'),
          );
        });

        testWidgets('by returning there after sign-in, with a profile', (
          tester,
        ) async {
          await signInFrom(tester, AdminPage.path, profile: _profile);

          expect(find.byType(AdminPage), findsOneWidget);
          expect(find.byType(MyRondaPage), findsNothing);
          expect(currentLocation(tester), equals(AdminPage.path));
        });

        testWidgets('by returning there after sign-in, without a profile', (
          tester,
        ) async {
          await signInFrom(tester, AdminPage.path);

          expect(find.byType(AdminPage), findsOneWidget);
          expect(find.byType(OnboardingPage), findsNothing);
        });

        testWidgets('but on to $MyRondaPage after sign-in without the claim', (
          tester,
        ) async {
          await signInFrom(
            tester,
            AdminPage.path,
            profile: _profile,
            admin: false,
          );

          expect(find.byType(MyRondaPage), findsOneWidget);
          expect(find.byType(AdminPage), findsNothing);
          verifyNever(rondaRepository.watchLatestProposal);
        });

        testWidgets('but on to onboarding after sign-in without the claim or '
            'a profile', (tester) async {
          await signInFrom(tester, AdminPage.path, admin: false);

          expect(find.byType(OnboardingPage), findsOneWidget);
          expect(find.byType(AdminPage), findsNothing);
        });

        testWidgets('by keeping the ask when sign-in is opened too early', (
          tester,
        ) async {
          await pumpSignedOut(tester);

          GoRouter.of(tester.element(find.byType(WelcomePage)))
              .go('${LoginPage.path}?$returnToParameter=${AdminPage.path}');
          await tester.pumpAndSettle();

          expect(find.byType(WelcomePage), findsOneWidget);
          expect(
            currentLocation(tester),
            equals('${WelcomePage.path}?$returnToParameter=${AdminPage.path}'),
          );
        });

        testWidgets('but nowhere else a welcome link names', (tester) async {
          await signInFrom(
            tester,
            '${WelcomePage.path}?$returnToParameter=${SettingsPage.path}',
            profile: _profile,
          );

          expect(find.byType(MyRondaPage), findsOneWidget);
          expect(find.byType(SettingsPage), findsNothing);
        });
      });

      testWidgets('by signing out from Ajustes after the confirmation', (
        tester,
      ) async {
        when(() => pushRepository.unregisterDevice(any()))
            .thenAnswer((_) async {});
        when(authRepository.signOut).thenAnswer((_) async {
          users.add(User.empty);
        });
        await pumpSignedIn(tester);
        await tester.tap(_tab('Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sign out of this account'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
        await tester.pumpAndSettle();

        verify(() => pushRepository.unregisterDevice(_user.id)).called(1);
        verify(authRepository.signOut).called(1);
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
