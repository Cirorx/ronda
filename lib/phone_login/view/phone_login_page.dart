import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/phone_login/phone_login.dart';

/// Sign-in with a code sent by SMS. It sits under the sign-in screen that
/// opened it, and its back button returns there.
class const PhoneLoginPage({super.key}) extends StatelessWidget {
  /// The path under each sign-in screen.
  static const segment = 'celular';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          PhoneLoginCubit(authRepository: context.read<AuthRepository>()),
      child: const PhoneLoginView(),
    );
  }
}
