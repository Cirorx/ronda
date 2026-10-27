import 'package:ronda_ui/ronda_ui.dart';

/// {@template chip_picker_option}
/// One choice in a [ChipPicker].
/// {@endtemplate}
class const ChipPickerOption({
  /// Stable id for this choice ("termo"). Never shown; it ends the chip's
  /// semantics identifier.
  required final String value,

  /// What the chip says ("Termo").
  required final String label,

  /// Whether the chip can be tapped.
  final bool enabled = true,

  /// An optional leading object icon.
  final Widget? avatar,
}) {
  /// {@macro chip_picker_option}
  this;
}

/// {@template chip_picker}
/// A wrap of pill chips: several at once ([multiSelect], the default) or one
/// of them.
///
/// It holds no state: [selected] comes in, [onChanged] reports the next set.
/// Each chip's semantics identifier is `<identifier>.<value>`.
/// {@endtemplate}
class const ChipPicker({
  /// Prefix of every chip's semantics identifier ("traes").
  required final String identifier,

  /// The choices, in display order.
  required final List<ChipPickerOption> options,

  /// The values currently chosen.
  required final Set<String> selected,

  /// Called with the values chosen after a tap.
  required final ValueChanged<Set<String>> onChanged,

  /// Whether several chips can be chosen at once.
  final bool multiSelect = true,
  super.key,
}) extends StatelessWidget {
  /// {@macro chip_picker}
  this;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Wrap(
      spacing: spacing.xs,
      runSpacing: spacing.xs,
      children: [for (final option in options) _chip(option)],
    );
  }

  Widget _chip(ChipPickerOption option) {
    final isSelected = selected.contains(option.value);
    final label = Text(option.label);
    final chip = multiSelect
        ? FilterChip(
            label: label,
            avatar: option.avatar,
            selected: isSelected,
            onSelected: option.enabled
                ? (chosen) => _toggle(option.value, chosen: chosen)
                : null,
          )
        : ChoiceChip(
            label: label,
            avatar: option.avatar,
            selected: isSelected,
            onSelected: option.enabled
                ? (chosen) => _choose(option.value, chosen: chosen)
                : null,
          );
    // Merged so the identifier sits on the chip's own node, with its tap
    // action, where Maestro looks for it.
    return MergeSemantics(
      child: Semantics(identifier: '$identifier.${option.value}', child: chip),
    );
  }

  void _toggle(String value, {required bool chosen}) {
    onChanged(chosen ? {...selected, value} : ({...selected}..remove(value)));
  }

  void _choose(String value, {required bool chosen}) {
    if (chosen) onChanged({value});
  }
}
