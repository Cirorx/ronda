import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Builds an admin screen ([child]) only once [AdminAccessCubit] has read
/// the admin claim on the signed-in account's token; until then, and for
/// anyone without it, a ring and "Revisando esta cuenta…". So the admin
/// screens' cubits never start for a member, and nothing they would read is
/// asked for. The router moves a member away; the server refuses them
/// anyway.
class const AdminGate({required final Widget child, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final access = context.watch<AdminAccessCubit>().state;
    if (access == AdminAccess.admin) return child;
    return Scaffold(
      body: SafeArea(child: LoadingStatus(context.l10n.adminChecking)),
    );
  }
}
