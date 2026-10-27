part of 'login_cubit.dart';

enum LoginStatus { initial, inProgress, success, failure }

/// What the login screen says when sign-in fails.
enum LoginError { network, other }

final class const LoginState({
  final LoginStatus status = LoginStatus.initial,
  final LoginError? error,
}) extends Equatable {
  @override
  List<Object?> get props => [status, error];
}
