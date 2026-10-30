import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// [Escribir un mail], under Maestro's [identifier].
class const EmailButton({
  required final String identifier,
  required final VoidCallback onPressed,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.mail_outline),
          label: Text(context.l10n.contactEmailButton),
        ),
      ),
    );
  }
}
