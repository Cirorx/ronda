import 'package:ronda_ui/ronda_ui.dart';

/// One cell of a [SlotGrid]: a day row and a time-band column, as indexes
/// into [SlotGrid.dayLabels] and [SlotGrid.bandLabels].
typedef SlotGridCell = ({int day, int band});

/// {@template slot_grid}
/// "¿Cuándo podés?": a day × time band (mañana / tarde / noche) grid where
/// the person marks every slot that works.
///
/// From [chipsTextScale] up it turns into one row of chips per day, which
/// holds at 200% text. It holds no state: [selected] comes in, [onChanged]
/// reports the next set. Each cell's semantics identifier is
/// `<identifier>.<day>.<band>` in both layouts. Cells shrink on touch-down
/// and take a ring when focused from a keyboard ([PressScale]); a mouse over
/// one tints it over [AppMotion.hover]. Marking a cell fills it and shows
/// its check at once: it is tapped many times in a row.
/// {@endtemplate}
class const SlotGrid({
  /// Prefix of every cell's semantics identifier ("horarios").
  required final String identifier,

  /// Row labels, one per day ("Lunes" … "Domingo").
  required final List<String> dayLabels,

  /// Column labels, one per time band ("Mañana", "Tarde", "Noche").
  required final List<String> bandLabels,

  /// What a screen reader says for a cell ("Martes de tarde").
  required final String Function(int day, int band) cellSemanticsLabel,

  /// The cells currently marked.
  required final Set<SlotGridCell> selected,

  /// Called with the marked cells after a tap.
  required final ValueChanged<Set<SlotGridCell>> onChanged,
  super.key,
}) extends StatelessWidget {
  /// {@macro slot_grid}
  this;

  static const _cellRadius = BorderRadius.all(Radius.circular(AppRadius.md));

  /// The text scale from which the grid becomes per-day chips.
  static const double chipsTextScale = AppTheme.largeTextScale;

  @override
  Widget build(BuildContext context) {
    return context.usesLargeText ? _buildChips(context) : _buildGrid(context);
  }

  Widget _buildGrid(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final gap = EdgeInsets.all(spacing.xxs);
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {0: IntrinsicColumnWidth()},
      children: [
        TableRow(
          children: [
            const SizedBox.shrink(),
            for (final band in bandLabels)
              ExcludeSemantics(
                child: Padding(
                  padding: gap,
                  child: Text(
                    band,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (final (day, dayLabel) in dayLabels.indexed)
          TableRow(
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(end: spacing.xs),
                child: Text(dayLabel, style: theme.textTheme.titleSmall),
              ),
              for (var band = 0; band < bandLabels.length; band++)
                Padding(
                  padding: gap,
                  child: _cell(
                    (day: day, band: band),
                    (cell, {required isSelected}) => PressScale(
                      borderRadius: _cellRadius,
                      child: InkWell(
                        onTap: () => _toggle(cell),
                        hoverDuration: AppMotion.hover,
                        borderRadius: _cellRadius,
                        child: _SlotCellBox(isSelected: isSelected),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildChips(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (day, dayLabel) in dayLabels.indexed) ...[
          if (day > 0) const Divider(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.xs,
              children: [
                Text(dayLabel, style: textTheme.titleSmall),
                Wrap(
                  spacing: spacing.xs,
                  runSpacing: spacing.xs,
                  children: [
                    for (final (band, bandLabel) in bandLabels.indexed)
                      _cell(
                        (day: day, band: band),
                        (cell, {required isSelected}) => PressScale(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(AppRadius.pill),
                          ),
                          child: FilterChip(
                            label: Text(bandLabel),
                            selected: isSelected,
                            onSelected: (_) => _toggle(cell),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// One tappable cell, with its identifier, label and state on one node.
  Widget _cell(
    SlotGridCell cell,
    Widget Function(SlotGridCell cell, {required bool isSelected}) builder,
  ) {
    final isSelected = selected.contains(cell);
    return Semantics(
      container: true,
      identifier: '$identifier.${cell.day}.${cell.band}',
      label: cellSemanticsLabel(cell.day, cell.band),
      button: true,
      selected: isSelected,
      onTap: () => _toggle(cell),
      excludeSemantics: true,
      child: builder(cell, isSelected: isSelected),
    );
  }

  void _toggle(SlotGridCell cell) {
    onChanged(
      selected.contains(cell)
          ? ({...selected}..remove(cell))
          : {...selected, cell},
    );
  }
}

class const _SlotCellBox({required final bool isSelected})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Ink(
      height: AppTheme.minTarget,
      decoration: BoxDecoration(
        color: isSelected ? scheme.primary : scheme.surfaceContainer,
        borderRadius: SlotGrid._cellRadius,
        border: isSelected
            ? null
            : Border.all(
                color: scheme.outlineVariant,
                width: AppTheme.borderWidth,
              ),
      ),
      child: Center(
        child: isSelected ? Icon(Icons.check, color: scheme.onPrimary) : null,
      ),
    );
  }
}
