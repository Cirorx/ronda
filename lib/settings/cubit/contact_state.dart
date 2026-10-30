part of 'contact_cubit.dart';

/// How the last attempt to reach someone went.
enum ContactStatus {
  /// Nothing failed.
  idle,

  /// No mail app opened.
  emailFailed,

  /// No dialer opened for [ContactState.helpline].
  callFailed,
}

final class const ContactState({
  /// Where members write to Ronda.
  required final String email,
  final ContactStatus status = ContactStatus.idle,

  /// The line whose call didn't open, with [ContactStatus.callFailed].
  final Helpline? helpline,
}) extends Equatable {
  @override
  List<Object?> get props => [email, status, helpline];
}
