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
