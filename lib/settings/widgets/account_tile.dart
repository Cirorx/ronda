import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/settings/cubit/account_cubit.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Entraste con Google" and the email, or "Entraste con tu celular" and the
/// number, from the [AccountCubit]. Read only: nothing to tap. Shows nothing
/// when the way in is unknown.
class const AccountTile({super.key}) extends StatelessWidget {
  /// Maestro's handle on the row.
  static const identifier = 'settings.account';

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountCubit>().state;
    if (account == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final address = account.displayAddress;
    final (icon, label) = switch (account.method) {
      SignInMethod.google => (
        Icons.account_circle_outlined,
        l10n.settingsAccountGoogle,
      ),
      SignInMethod.phone => (Icons.smartphone, l10n.settingsAccountPhone),
    };
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: address == null ? null : Text(address),
        ),
      ),
    );
  }
}
