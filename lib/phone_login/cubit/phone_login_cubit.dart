import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda/phone_login/models/models.dart';

part 'phone_login_state.dart';

/// Signs the person in with a code sent by SMS to their mobile: sends it,
/// counts down to the next resend, and checks the typed code. Where they go
/// next is the router's call: it follows `AppBloc`, not this cubit, so an
/// Android phone that reads the SMS by itself moves on with no tap.
///
/// The number stays in this cubit's memory and Firebase Auth only.
class PhoneLoginCubit extends Cubit<PhoneLoginState> {
  new({required this._authRepository, this._now = DateTime.now})
    : super(const PhoneLoginState());

  final AuthRepository _authRepository;
  final DateTime Function() _now;
  Timer? _countdown;

  void numberChanged(String value) => emit(
    state.copyWith(
      number: PhoneNumberInput.dirty(value),
      showInputError: false,
      error: () => null,
    ),
  );

  void codeChanged(String value) => emit(
    state.copyWith(
      code: SmsCode.dirty(value),
      showInputError: false,
      error: () => null,
    ),
  );

  /// [Mandame el código]: sends the first code to a valid number.
  Future<void> sendCode() async {
    if (state.busy) return;
    final phoneNumber = state.number.phoneNumber;
    if (phoneNumber == null) {
      emit(state.copyWith(showInputError: true));
      return;
    }
    await _send(phoneNumber, resending: null);
  }

  /// "Mandame otro código", once the cooldown is over.
  Future<void> resendCode() async {
    final verification = state.verification;
    if (state.busy ||
        verification == null ||
        state.noMoreResends ||
        state.secondsToResend > 0) {
      return;
    }
    await _send(verification.phoneNumber, resending: verification);
  }

  Future<void> _send(
    PhoneNumber phoneNumber, {
    required PhoneVerification? resending,
  }) async {
    emit(state.copyWith(status: PhoneLoginStatus.sending, error: () => null));
    try {
      final verification = await _authRepository.sendPhoneCode(
        phoneNumber,
        resending: resending,
      );
      if (verification == null) {
        // Android verified the number without a code: already signed in.
        emit(state.copyWith(status: PhoneLoginStatus.success));
        return;
      }
      emit(
        state.copyWith(
          step: PhoneLoginStep.code,
          status: PhoneLoginStatus.idle,
          verification: verification,
          code: const SmsCode.pure(),
          resent: resending != null,
          showInputError: false,
          secondsToResend: _secondsTo(verification.resendAvailableAt),
        ),
      );
      _startCountdown();
    } on SendPhoneCodeFailure catch (failure) {
      emit(
        state.copyWith(
          status: PhoneLoginStatus.idle,
          error: () => switch (failure.reason) {
            SendPhoneCodeFailureReason.cancelled => null,
            SendPhoneCodeFailureReason.invalidNumber =>
              PhoneLoginError.invalidNumber,
            SendPhoneCodeFailureReason.tooManyRequests ||
            SendPhoneCodeFailureReason.tooSoon =>
              PhoneLoginError.tooManyRequests,
            SendPhoneCodeFailureReason.unavailable =>
              PhoneLoginError.unavailable,
            SendPhoneCodeFailureReason.network => PhoneLoginError.network,
            SendPhoneCodeFailureReason.unknown => PhoneLoginError.other,
          },
        ),
      );
    }
  }

  /// [Entrar]: checks the typed code.
  Future<void> confirmCode() async {
    final verification = state.verification;
    if (state.busy || verification == null) return;
    if (state.code.isNotValid) {
      emit(state.copyWith(showInputError: true));
      return;
    }
    emit(
      state.copyWith(status: PhoneLoginStatus.confirming, error: () => null),
    );
    try {
      await _authRepository.confirmPhoneCode(verification, state.code.digits);
      _countdown?.cancel();
      emit(state.copyWith(status: PhoneLoginStatus.success));
    } on ConfirmPhoneCodeFailure catch (failure) {
      emit(
        state.copyWith(
          status: PhoneLoginStatus.idle,
          error: () => switch (failure.reason) {
            ConfirmPhoneCodeFailureReason.invalidCode =>
              PhoneLoginError.wrongCode,
            ConfirmPhoneCodeFailureReason.expired =>
              PhoneLoginError.expiredCode,
            ConfirmPhoneCodeFailureReason.tooManyRequests =>
              PhoneLoginError.tooManyRequests,
            ConfirmPhoneCodeFailureReason.network => PhoneLoginError.network,
            ConfirmPhoneCodeFailureReason.userDisabled ||
            ConfirmPhoneCodeFailureReason.unknown => PhoneLoginError.other,
          },
        ),
      );
    }
  }

  /// "Cambiar el número": back to the number, which stays typed. The
  /// cooldowns start over with the next number.
  void changeNumber() {
    if (state.busy) return;
    _countdown?.cancel();
    emit(PhoneLoginState(number: state.number));
  }

  void _startCountdown() {
    _countdown?.cancel();
    if (state.secondsToResend == 0) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final seconds = _secondsTo(state.verification?.resendAvailableAt);
      emit(state.copyWith(secondsToResend: seconds));
      if (seconds == 0) timer.cancel();
    });
  }

  /// Whole seconds left until [at], rounded up; 0 once it has passed or
  /// when there is no such time.
  int _secondsTo(DateTime? at) {
    if (at == null) return 0;
    final left = at.difference(_now());
    if (left <= Duration.zero) return 0;
    return (left.inMilliseconds / Duration.millisecondsPerSecond).ceil();
  }

  @override
  Future<void> close() {
    _countdown?.cancel();
    return super.close();
  }
}
