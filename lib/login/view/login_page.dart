import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/login/login.dart';

/// The sign-in screen: Google only.
class const LoginPage({super.key}) extends StatelessWidget {
  static const path = '/entrar';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          LoginCubit(authRepository: context.read<AuthRepository>()),
      child: const LoginView(),
    );
  }
}
