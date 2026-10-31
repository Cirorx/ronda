import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/settings/cubit/contact_cubit.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template contact_failure_note}
/// Where a mail app or a dialer should have opened: when it didn't (the
/// [ContactCubit] above is at [failure]), a banner right under the action
/// says so, with the address or the number to use by hand. It swaps in and
/// is read out; a second try that fails again shows it again.
/// {@endtemplate}
class const ContactFailureNote({
  /// Which failure this spot reports: [ContactStatus.emailFailed] under
  /// [Escribir un mail], [ContactStatus.callFailed] under the helplines.
  required final ContactStatus failure,
  super.key,
}) extends StatelessWidget {
  /// {@macro contact_failure_note}
  this;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ContactCubit>().state;
    final message = switch ((state.status, state.helpline)) {
      (final status, _) when status != failure => null,
      (ContactStatus.callFailed, final helpline?) => l10n.contactCallFailed(
        helpline.number,
      ),
      _ => l10n.contactEmailFailed(state.email),
    };
    return RondaSwap(
      layoutBuilder: _topStart,
      child: switch (message) {
        final message? => Padding(
          key: ValueKey(message),
          padding: EdgeInsetsDirectional.only(top: context.appSpacing.sm),
          child: NoteBanner(
            variant: NoteBannerVariant.warning,
            message: message,
          ),
        ),
        null => const SizedBox.shrink(key: ValueKey(ContactStatus.idle)),
      },
    );
  }

  static Widget _topStart(Widget? current, List<Widget> previous) =>
      Stack(children: [...previous, ?current]);
}
