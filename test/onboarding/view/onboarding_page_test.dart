import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/onboarding/view/steps/steps.dart';

import '../../helpers/helpers.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockProfileRepository extends Mock implements ProfileRepository;

class _MockNeedsRepository extends Mock implements NeedsRepository;

class _MockOnboardingRepository extends Mock implements OnboardingRepository;

void main() {
  group(OnboardingPage, () {
    late AppBloc appBloc;

    setUp(() {
      appBloc = _MockAppBloc();
      when(() => appBloc.state).thenReturn(
        const AppState(
          status: AppStatus.onboarding,
          user: User(id: 'demo-uid'),
        ),
      );
    });

    testWidgets('provides an $OnboardingCubit on the first question', (
      tester,
    ) async {
      await tester.pumpApp(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ProfileRepository>.value(
              value: _MockProfileRepository(),
            ),
            RepositoryProvider<NeedsRepository>.value(
              value: _MockNeedsRepository(),
            ),
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
              value: _MockProfileRepository(),
            ),
            RepositoryProvider<NeedsRepository>.value(
              value: _MockNeedsRepository(),
            ),
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
