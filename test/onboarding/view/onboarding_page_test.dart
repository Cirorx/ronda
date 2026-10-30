import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/onboarding/view/steps/steps.dart';
import 'package:ronda/payoff/payoff.dart';
import 'package:ronda/welcome/welcome.dart';

import '../../helpers/helpers.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockProfileRepository extends Mock implements ProfileRepository;

class _MockNeedsRepository extends Mock implements NeedsRepository;

class _MockOnboardingRepository extends Mock implements OnboardingRepository;

class _MockGoRouter extends Mock implements GoRouter;

final _held = Profile(
  firstName: 'Marta',
  ageBand: AgeBand.sixties,
  barrio: Barrio.solymarNorte,
  pretexts: const {Pretext.mate},
  slots: {const Slot(SlotDay.sunday, SlotBand.afternoon)},
  brings: const {Bring.pan},
);

void main() {
  group(OnboardingPage, () {
    late AppBloc appBloc;
    late ProfileRepository profileRepository;
    late NeedsRepository needsRepository;
    late GoRouter router;

    setUpAll(() {
      registerFallbackValue(Needs.none);
      registerFallbackValue(_held);
    });

    setUp(() {
      appBloc = _MockAppBloc();
      when(() => appBloc.state).thenReturn(
        const AppState(
          status: AppStatus.onboarding,
          user: User(id: 'demo-uid'),
        ),
      );
      profileRepository = _MockProfileRepository();
      needsRepository = _MockNeedsRepository();
      when(profileRepository.heldAnswers).thenAnswer((_) async => null);
      when(needsRepository.read).thenAnswer((_) async => Needs.none);
      router = _MockGoRouter();
      when(() => router.go(any())).thenReturn(null);
    });

    /// Pumps the page signed out, with [held] answers on the phone.
    Future<void> pumpSignedOut(WidgetTester tester, {Profile? held}) async {
      when(() => appBloc.state)
          .thenReturn(const AppState(status: AppStatus.unauthenticated));
      when(profileRepository.heldAnswers).thenAnswer((_) async => held);
      await tester.pumpApp(
        InheritedGoRouter(
          goRouter: router,
          child: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<ProfileRepository>.value(
                value: profileRepository,
              ),
              RepositoryProvider<NeedsRepository>.value(value: needsRepository),
            ],
            child: BlocProvider.value(
              value: appBloc,
              child: const OnboardingPage(),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('signed out, opens the answers held on the phone on the '
        'read-back', (tester) async {
      await pumpSignedOut(tester, held: _held);

      expect(find.byType(ReviewStep), findsOneWidget);
      expect(find.text('Marta'), findsOneWidget);
    });

    testWidgets('signed out, holds the answers and goes to the payoff on '
        '"Está bien, guardalo"', (tester) async {
      when(() => needsRepository.save(any())).thenAnswer((_) async {});
      when(() => profileRepository.holdAnswers(any())).thenAnswer((_) async {});
      await pumpSignedOut(tester, held: _held);

      await tester.tap(find.bySemanticsIdentifier(ReviewStep.saveIdentifier));
      await tester.pump();

      verify(() => profileRepository.holdAnswers(_held)).called(1);
      verify(() => router.go(PayoffPage.path)).called(1);
    });

    testWidgets('signed out, leaves for the welcome doors from the first '
        'question', (tester) async {
      await pumpSignedOut(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();

      verify(() => router.go(WelcomePage.path)).called(1);
    });

    testWidgets('signed in, has nowhere to leave to from the first question', (
      tester,
    ) async {
      await tester.pumpApp(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ProfileRepository>.value(
              value: profileRepository,
            ),
            RepositoryProvider<NeedsRepository>.value(value: needsRepository),
          ],
          child: BlocProvider.value(
            value: appBloc,
            child: const OnboardingPage(),
          ),
        ),
      );

      expect(
        tester.widget<OnboardingView>(find.byType(OnboardingView)).onLeave,
        isNull,
      );
    });

    testWidgets('provides an $OnboardingCubit on the first question', (
      tester,
    ) async {
      await tester.pumpApp(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ProfileRepository>.value(
              value: profileRepository,
            ),
            RepositoryProvider<NeedsRepository>.value(value: needsRepository),
          ],
          child: BlocProvider.value(
            value: appBloc,
            child: const OnboardingPage(),
          ),
        ),
      );

      expect(find.byType(OnboardingView), findsOneWidget);
      expect(find.byType(PretextsStep), findsOneWidget);
      final context = tester.element(find.byType(OnboardingView));
      expect(
        context.read<OnboardingCubit>().state,
        equals(const OnboardingState()),
      );
    });

    testWidgets('opens on the recorder after "Con un audio"', (tester) async {
      when(() => appBloc.state).thenReturn(
        const AppState(
          status: AppStatus.onboarding,
          user: User(id: 'demo-uid'),
          door: OnboardingDoor.voice,
        ),
      );
      final onboardingRepository = _MockOnboardingRepository();
      when(onboardingRepository.startVoiceNote).thenAnswer((_) async {});
      when(onboardingRepository.discardVoiceNote).thenAnswer((_) async {});

      await tester.pumpApp(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ProfileRepository>.value(
              value: profileRepository,
            ),
            RepositoryProvider<NeedsRepository>.value(value: needsRepository),
            RepositoryProvider<OnboardingRepository>.value(
              value: onboardingRepository,
            ),
          ],
          child: BlocProvider.value(
            value: appBloc,
            child: const OnboardingPage(),
          ),
        ),
      );

      expect(find.byType(VoiceNoteStep), findsOneWidget);
    });
  });
}
