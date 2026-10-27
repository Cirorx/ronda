part of 'app_bloc.dart';

enum AppStatus { authenticated, unauthenticated }

final class const AppState({
  required final AppStatus status,
  final User user = User.empty,
}) extends Equatable {
  /// [AppStatus.authenticated] with [user], or [AppStatus.unauthenticated]
  /// when [user] is [User.empty].
  factory fromUser(User user) => user.isEmpty
      ? const AppState(status: AppStatus.unauthenticated)
      : AppState(status: AppStatus.authenticated, user: user);

  @override
  List<Object> get props => [status, user];
}
