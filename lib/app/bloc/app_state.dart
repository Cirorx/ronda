part of 'app_bloc.dart';

enum AppStatus {
  /// Nobody is signed in.
  unauthenticated,

  /// Signed in; whether a profile exists is not known yet.
  loadingProfile,

  /// Signed in without a profile: onboarding comes next.
  onboarding,

  /// Signed in with a profile.
  authenticated,
}

/// The welcome door the person went through.
enum OnboardingDoor {
  /// "Con un audio": onboarding opens on the recorder.
  voice,

  /// "Tocando botones": the seven questions.
  buttons,
}

final class const AppState({
  required final AppStatus status,
  final User user = User.empty,

  /// Conditions accepted on the welcome screen and not yet written to
  /// `users/{uid}`, because nobody was signed in when the door was tapped.
  final TermsAcceptance? pendingTerms,

  /// The welcome door tapped last, so onboarding opens on its path after
  /// sign-in.
  final OnboardingDoor door = OnboardingDoor.buttons,

  /// Whether this phone has shown "¿Cómo funciona?"; until it has, a
  /// signed-out person opening the app sees it before the welcome doors.
  final bool walkthroughSeen = false,
}) extends Equatable {
  /// [AppStatus.unauthenticated] for [User.empty]; otherwise
  /// [AppStatus.loadingProfile] for [user], until the profile is read.
  factory fromUser(User user, {bool walkthroughSeen = false}) => user.isEmpty
      ? AppState(
          status: AppStatus.unauthenticated,
          walkthroughSeen: walkthroughSeen,
        )
      : AppState(
          status: AppStatus.loadingProfile,
          user: user,
          walkthroughSeen: walkthroughSeen,
        );

  /// This state with [status].
  AppState withStatus(AppStatus status) => AppState(
    status: status,
    user: user,
    pendingTerms: pendingTerms,
    door: door,
    walkthroughSeen: walkthroughSeen,
  );

  /// This state with [pendingTerms], or none when `null`.
  AppState withPendingTerms(TermsAcceptance? pendingTerms) => AppState(
    status: status,
    user: user,
    pendingTerms: pendingTerms,
    door: door,
    walkthroughSeen: walkthroughSeen,
  );

  /// This state with [door].
  AppState withDoor(OnboardingDoor door) => AppState(
    status: status,
    user: user,
    pendingTerms: pendingTerms,
    door: door,
    walkthroughSeen: walkthroughSeen,
  );

  /// This state once "¿Cómo funciona?" was shown.
  AppState withWalkthroughSeen() => AppState(
    status: status,
    user: user,
    pendingTerms: pendingTerms,
    door: door,
    walkthroughSeen: true,
  );

  @override
  List<Object?> get props => [
    status,
    user,
    pendingTerms,
    door,
    walkthroughSeen,
  ];
}
