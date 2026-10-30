import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/settings/cubit/contact_cubit.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// When no mail app or dialer opened, says so in a snack bar with the
/// address or the number to use by hand. Reads the [ContactCubit] above it.
class const ContactFailureListener({required final Widget child, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocListener<ContactCubit, ContactState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status != ContactStatus.idle,
      listener: (context, state) {
        final l10n = context.l10n;
        final message = switch ((state.status, state.helpline)) {
          (ContactStatus.callFailed, final helpline?) => l10n.contactCallFailed(
            helpline.number,
          ),
          _ => l10n.contactEmailFailed(state.email),
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      child: child,
    );
  }
}
