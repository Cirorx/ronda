part of 'phone_login_cubit.dart';

/// Which of the screen's two steps is open.
enum PhoneLoginStep {
  /// "¿Cuál es tu celular?": the number, then [Mandame el código].
  number,

  /// "Escribí el código": the six digits, a resend and "Cambiar el número".
  code,
}

enum PhoneLoginStatus {
  /// Waiting for the person.
  idle,

  /// A code is on its way.
  sending,

  /// The typed code is being checked.
  confirming,

  /// Signed in; the router moves on once `AppBloc` hears it.
  success,
}

/// What the screen says when a step fails.
enum PhoneLoginError {
  invalidNumber,
  tooManyRequests,
  unavailable,
  wrongCode,
  expiredCode,
  network,
  other,
}

/// {@template phone_login_state}
/// The phone sign-in screen. It holds the number only in memory, and its
/// [toString] hides it: the bloc observer logs every state.
/// {@endtemplate}
final class const PhoneLoginState({
  final PhoneLoginStep step = PhoneLoginStep.number,
  final PhoneLoginStatus status = PhoneLoginStatus.idle,
  final PhoneNumberInput number = const PhoneNumberInput.pure(),
  final SmsCode code = const SmsCode.pure(),
  final PhoneVerification? verification,

  /// Seconds until another code may be asked for; 0 once it may.
  final int secondsToResend = 0,

  /// Whether the code on screen came from a resend ("Te mandamos otro").
  final bool resent = false,

  /// Whether the open step's field says why it is not valid: after a tap
  /// on its button, until the person types again.
  final bool showInputError = false,
  final PhoneLoginError? error,
}) extends Equatable {
  /// {@macro phone_login_state}
  this;

  /// Whether a request is out or the person is already in, so nothing
  /// else may be pressed.
  bool get busy => status != PhoneLoginStatus.idle;

  /// Whether no more codes may be asked for on this screen.
  bool get noMoreResends =>
      verification != null && verification?.resendAvailableAt == null;

  PhoneLoginState copyWith({
    PhoneLoginStep? step,
    PhoneLoginStatus? status,
    PhoneNumberInput? number,
    SmsCode? code,
    PhoneVerification? verification,
    int? secondsToResend,
    bool? resent,
    bool? showInputError,
    PhoneLoginError? Function()? error,
  }) => PhoneLoginState(
    step: step ?? this.step,
    status: status ?? this.status,
    number: number ?? this.number,
    code: code ?? this.code,
    verification: verification ?? this.verification,
    secondsToResend: secondsToResend ?? this.secondsToResend,
    resent: resent ?? this.resent,
    showInputError: showInputError ?? this.showInputError,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [
    step,
    status,
    number,
    code,
    verification,
    secondsToResend,
    resent,
    showInputError,
    error,
  ];

  /// Leaves the number, the code and the verification out.
  @override
  String toString() =>
      'PhoneLoginState($step, $status, secondsToResend: $secondsToResend, '
      'resent: $resent, showInputError: $showInputError, error: $error)';
}
