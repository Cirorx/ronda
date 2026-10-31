import 'package:contact_repository/contact_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/settings/cubit/contact_cubit.dart';
import 'package:ronda/settings/widgets/contact_failure_note.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "¿Necesitás hablar con alguien ahora?": the Línea de Prevención del
/// Suicidio (0800 0767, *0767) and Emergencias (911), each number a button
/// that opens the dialer, and under them what to dial by hand when the
/// dialer didn't open. Reads the [ContactCubit] above it.
class const HelplineBlock({super.key}) extends StatelessWidget {
  /// Maestro's handle on a [Helpline]'s button.
  static String identifier(Helpline helpline) => 'helpline.${helpline.name}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final cubit = context.read<ContactCubit>();

    Widget number(Helpline helpline) => Semantics(
      container: true,
      identifier: identifier(helpline),
      label: l10n.helplineCall(helpline.number),
      button: true,
      onTap: () => cubit.helplineTapped(helpline),
      excludeSemantics: true,
      child: OutlinedButton.icon(
        onPressed: () => cubit.helplineTapped(helpline),
        icon: const Icon(Icons.call_outlined),
        label: Text(helpline.number),
      ),
    );

    Widget line(String name, List<Helpline> helplines) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.xs,
      children: [
        Text(name, style: textTheme.bodyLarge),
        Wrap(
          spacing: spacing.xs,
          runSpacing: spacing.xs,
          children: [for (final helpline in helplines) number(helpline)],
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.md,
              children: [
                Semantics(
                  header: true,
                  child: Text(l10n.helplineTitle, style: textTheme.titleMedium),
                ),
                line(l10n.helplineSuicidePrevention, const [
                  Helpline.suicidePrevention,
                  Helpline.suicidePreventionMobile,
                ]),
                line(l10n.helplineEmergencies, const [Helpline.emergencies]),
              ],
            ),
            const ContactFailureNote(failure: ContactStatus.callFailed),
          ],
        ),
      ),
    );
  }
}
