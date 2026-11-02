import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';

/// Ajustes: how the signed-in person enters Ronda, with Google or a phone
/// number, and the email or the number, read once when the tab opens.
///
/// The state is null when nobody is signed in or Firebase Auth knows neither
/// way in; the row then doesn't show.
class AccountCubit extends Cubit<SignInAccount?> {
  new({required AuthRepository authRepository})
    : super(authRepository.signInAccount);
}
