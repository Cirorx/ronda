import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Onboarding for a signed-in person without a profile: the recorder when
/// they came through "Con un audio", the questions otherwise.
class const OnboardingPage({super.key}) extends StatelessWidget {
  static const path = '/sumarte';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OnboardingCubit(
        uid: context.read<AppBloc>().state.user.id,
        profileRepository: context.read<ProfileRepository>(),
        needsRepository: context.read<NeedsRepository>(),
        startWithVoice:
            context.read<AppBloc>().state.door == OnboardingDoor.voice,
      ),
      child: const OnboardingView(),
    );
  }
}
