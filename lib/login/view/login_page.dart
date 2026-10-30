import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/login/login.dart';

/// Why the sign-in screen opened, which sets what it says first.
enum LoginReason {
  /// After the payoff, in the buttons path: "Guardá tu lugar".
  keepSeat,

  /// After "Con un audio": the server reads the audio, so sign-in comes
  /// before recording.
  voice,

  /// Signing in to return somewhere (`?from=/admin`): "Primero, entrá con
  /// tu cuenta".
  signIn,
}

/// The sign-in screen: Google only. It sits under the screen that opened
/// it (the welcome doors or the payoff), and its back button returns there.
class const LoginPage({
  /// Why it opened.
  final LoginReason reason = LoginReason.signIn,
  super.key,
}) extends StatelessWidget {
  /// The path under the screen that opens it.
  static const segment = 'entrar';

  /// Sign-in under the welcome screen: the voice door, or a return to
  /// `/admin`.
  static const path = '/bienvenida/$segment';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          LoginCubit(authRepository: context.read<AuthRepository>()),
      child: LoginView(reason: reason),
    );
  }
}
