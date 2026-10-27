import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/login/login.dart';

/// The sign-in screen: Google only. It comes after a welcome door, so it
/// sits under the welcome screen and its back button returns there.
class const LoginPage({super.key}) extends StatelessWidget {
  /// The path under the welcome screen's.
  static const segment = 'entrar';

  static const path = '/bienvenida/$segment';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          LoginCubit(authRepository: context.read<AuthRepository>()),
      child: const LoginView(),
    );
  }
}
