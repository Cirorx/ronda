import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'login_state.dart';

/// Signs the person in with Google. Where they go next is the router's
/// call: it follows `AppBloc`, not this cubit.
class LoginCubit extends Cubit<LoginState> {
  new({required this._authRepository}) : super(const LoginState());

  final AuthRepository _authRepository;

  /// Signs in with Google. Closing the picker returns to
  /// [LoginStatus.initial] without an error.
  Future<void> signInWithGoogle() async {
    if (state.status == LoginStatus.inProgress) return;
    emit(const LoginState(status: LoginStatus.inProgress));
    try {
      await _authRepository.signInWithGoogle();
      emit(const LoginState(status: LoginStatus.success));
    } on SignInWithGoogleFailure catch (failure) {
      emit(switch (failure.reason) {
        SignInWithGoogleFailureReason.cancelled => const LoginState(),
        SignInWithGoogleFailureReason.network => const LoginState(
          status: LoginStatus.failure,
          error: LoginError.network,
        ),
        SignInWithGoogleFailureReason.userDisabled ||
        SignInWithGoogleFailureReason.unknown => const LoginState(
          status: LoginStatus.failure,
          error: LoginError.other,
        ),
      });
    }
  }
}
