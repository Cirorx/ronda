import 'package:ronda_ui/ronda_ui.dart';

/// {@template read_back_field}
/// One line of a [ReadBackCard]: what Ronda understood, and how to change it.
/// {@endtemplate}
class const ReadBackField({
  /// Stable id for this field ("barrio"). Never shown; it ends the edit
  /// action's semantics identifier.
  required final String id,

  /// What the value is ("Barrio").
  required final String label,

  /// What Ronda understood ("Solymar Norte").
  required final String value,

  /// What a screen reader says for the edit action ("Cambiar barrio").
  required final String editSemanticsLabel,

  /// Called when the person taps the edit action.
  required final VoidCallback onEdit,
}) {
  /// {@macro read_back_field}
  this;
}

/// {@template read_back_card}
/// The read-back after a voice note ("¿Entendimos bien?"): every field Ronda
/// understood, each with its own edit action.
///
/// Each edit action's semantics identifier is `<identifier>.<field id>`.
/// {@endtemplate}
class const ReadBackCard({
  /// Prefix of every edit action's semantics identifier ("lectura").
  required final String identifier,

  /// The fields, in reading order.
  required final List<ReadBackField> fields,

  /// What every edit action says ("Cambiar").
  required final String editLabel,
  super.key,
}) extends StatelessWidget {
  /// {@macro read_back_card}
  this;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.xxs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, field) in fields.indexed) ...[
              if (index > 0) const Divider(),
              _FieldRow(
                field: field,
                editLabel: editLabel,
                identifier: '$identifier.${field.id}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class const _FieldRow({
  required final ReadBackField field,
  required final String editLabel,
  required final String identifier,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      child: Row(
        spacing: spacing.xs,
        children: [
          Expanded(
            child: MergeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.label,
                    style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(field.value, style: textTheme.titleMedium),
                ],
              ),
            ),
          ),
          Semantics(
            container: true,
            identifier: identifier,
            label: field.editSemanticsLabel,
            button: true,
            onTap: field.onEdit,
            excludeSemantics: true,
            child: TextButton(
              onPressed: field.onEdit,
              style: TextButton.styleFrom(
                textStyle: textTheme.labelMedium?.copyWith(
                  decoration: TextDecoration.underline,
                ),
              ),
              child: Text(editLabel),
            ),
          ),
        ],
      ),
    );
  }
}
