import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/payoff/payoff.dart';
import 'package:ronda/welcome/welcome.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Onboarding: the recorder when the person came through "Con un audio",
/// the questions otherwise.
///
/// Signed out (the buttons door), the read-back holds the answers on this
/// phone and moves on to the payoff, and back from the first question
/// returns to the welcome doors. Signed in, answers held on this phone are
/// saved as soon as it opens.
class const OnboardingPage({super.key}) extends StatelessWidget {
  static const path = '/sumarte';

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppBloc>().state;
    return BlocProvider(
      create: (context) {
        final cubit = OnboardingCubit(
          uid: app.user.id,
          profileRepository: context.read<ProfileRepository>(),
          needsRepository: context.read<NeedsRepository>(),
          startWithVoice: app.door == OnboardingDoor.voice,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: BlocListener<OnboardingCubit, OnboardingState>(
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            current.status == OnboardingStatus.held,
        listener: (context, _) => context.go(PayoffPage.path),
        child: OnboardingView(
          onLeave: app.user.isEmpty ? () => context.go(WelcomePage.path) : null,
        ),
      ),
    );
  }
}
