import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/admin/cubit/rsvp_push_cubit.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "El ¿Venís? de esta semana": what the weekly push does on its own, and
/// "Mandarlo ahora" with what came of it. Reads the [RsvpPushCubit] above.
class const RsvpPushSection({super.key}) extends StatelessWidget {
  /// Maestro's handle on the button.
  static const sendIdentifier = 'admin_rsvp_send';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final state = context.watch<RsvpPushCubit>().state;
    final sending = state.status == RsvpPushStatus.sending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.xs,
      children: [
        Text(l10n.adminRsvpTitle, style: textTheme.titleMedium),
        Text(l10n.adminRsvpBody, style: textTheme.bodyMedium),
        MergeSemantics(
          child: Semantics(
            identifier: sendIdentifier,
            child: OutlinedButton(
              onPressed: sending
                  ? null
                  : context.read<RsvpPushCubit>().sendTapped,
              child: Text(sending ? l10n.adminRsvpSending : l10n.adminRsvpSend),
            ),
          ),
        ),
        if (state.status == RsvpPushStatus.failed)
          NoteBanner(
            variant: NoteBannerVariant.warning,
            message: l10n.adminActionError,
          ),
        if (state.result case final result?)
          Semantics(
            liveRegion: true,
            child: Text(
              [
                l10n.adminRsvpSent(result.messages),
                if (result.already > 0) l10n.adminRsvpAlready(result.already),
                if (result.held > 0) l10n.adminRsvpHeld,
              ].join(' '),
              style: textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}
