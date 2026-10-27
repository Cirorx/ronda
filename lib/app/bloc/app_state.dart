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

final class const AppState({
  required final AppStatus status,
  final User user = User.empty,

  /// Conditions accepted on the welcome screen and not yet written to
  /// `users/{uid}`, because nobody was signed in when the door was tapped.
  final TermsAcceptance? pendingTerms,
}) extends Equatable {
  /// [AppStatus.unauthenticated] for [User.empty]; otherwise
  /// [AppStatus.loadingProfile] for [user], until the profile is read.
  factory fromUser(User user) => user.isEmpty
      ? const AppState(status: AppStatus.unauthenticated)
      : AppState(status: AppStatus.loadingProfile, user: user);

  /// This state with [status].
  AppState withStatus(AppStatus status) =>
      AppState(status: status, user: user, pendingTerms: pendingTerms);

  /// This state with [pendingTerms], or none when `null`.
  AppState withPendingTerms(TermsAcceptance? pendingTerms) =>
      AppState(status: status, user: user, pendingTerms: pendingTerms);

  @override
  List<Object?> get props => [status, user, pendingTerms];
}
