part of 'app_bloc.dart';

sealed class AppEvent extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// Start following sign-ins and sign-outs.
final class AppUserSubscriptionRequested extends AppEvent {
  const new();
}

/// The person tapped a door on the welcome screen, which accepts the
/// conditions linked under it.
final class AppTermsAccepted extends AppEvent {
  const new();
}

/// Firebase Auth reported a sign-in or a sign-out.
final class const _AppUserChanged(final User user) extends AppEvent {
  @override
  List<Object> get props => [user];
}
