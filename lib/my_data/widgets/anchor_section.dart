import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_data/cubit/my_data_cubit.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Casa and trabajo on "Mis datos": each barrio with «Cambiar» and its
/// "También barrios vecinos" switch, and «Agregar trabajo» or «Sacar
/// trabajo». A barrio is picked on a sheet with onboarding's
/// [BarrioPicker].
class const AnchorSection({super.key}) extends StatelessWidget {
  /// Maestro's handles; the switches and buttons add `.home` or `.work`.
  static const changeIdentifier = 'myData.change';
  static const neighboursIdentifier = 'myData.neighbours';
  static const addWorkIdentifier = 'myData.addWork';
  static const removeWorkIdentifier = 'myData.removeWork';

  /// The picker sheet's chips and search field.
  static const pickerIdentifier = 'myData.barrio';
  static const searchIdentifier = 'myData.barrio.search';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final theme = Theme.of(context);
    final (home, work) = context.select<MyDataCubit, (Anchor?, Anchor?)>(
      (cubit) => (cubit.state.home, cubit.state.work),
    );
    final cubit = context.read<MyDataCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (home != null)
          _AnchorRow(
            kind: AnchorKind.home,
            label: l10n.myDataHome,
            anchor: home,
            onChange: () => _pick(context, home.barrio, cubit.homeChanged),
            onNeighbours: (on) => cubit.homeNeighboursChanged(neighbours: on),
          ),
        if (work != null) ...[
          _AnchorRow(
            kind: AnchorKind.work,
            label: l10n.myDataWork,
            anchor: work,
            onChange: () => _pick(
              context,
              work.barrio,
              cubit.workChanged,
              excluded: home?.barrio,
            ),
            onNeighbours: (on) => cubit.workNeighboursChanged(neighbours: on),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              identifier: removeWorkIdentifier,
              child: TextButton(
                onPressed: cubit.workRemoved,
                child: Text(l10n.myDataRemoveWork),
              ),
            ),
          ),
        ] else ...[
          SizedBox(height: spacing.sm),
          Text(
            l10n.myDataWorkBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: spacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              identifier: addWorkIdentifier,
              child: OutlinedButton(
                onPressed: () => _pick(
                  context,
                  null,
                  cubit.workChanged,
                  excluded: home?.barrio,
                ),
                child: Text(l10n.myDataAddWork),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// The barrio sheet: picking one closes it and hands it to [onPicked].
  static Future<void> _pick(
    BuildContext context,
    Barrio? selected,
    ValueChanged<Barrio> onPicked, {
    Barrio? excluded,
  }) {
    final l10n = context.l10n;
    return showRondaSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(sheetContext.appSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: sheetContext.appSpacing.md,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.myDataPickTitle,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              BarrioPicker(
                identifier: pickerIdentifier,
                searchIdentifier: searchIdentifier,
                selected: selected,
                excluded: excluded,
                onChanged: (barrio) {
                  onPicked(barrio);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class const _AnchorRow({
  required final AnchorKind kind,
  required final String label,
  required final Anchor anchor,
  required final VoidCallback onChange,
  required final ValueChanged<bool> onNeighbours,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MergeSemantics(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            subtitle: Text(l10n.barrio(anchor.barrio)),
            trailing: Semantics(
              identifier: '${AnchorSection.changeIdentifier}.${kind.name}',
              child: TextButton(
                onPressed: onChange,
                child: Text(l10n.myDataChangeBarrio),
              ),
            ),
          ),
        ),
        Semantics(
          identifier: '${AnchorSection.neighboursIdentifier}.${kind.name}',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.myDataNeighbours),
            subtitle: Text(
              l10n.myDataNeighboursBody(
                anchor.withNeighbours(neighbours: true).reachBlocks.floor(),
              ),
            ),
            value: anchor.neighbours,
            onChanged: onNeighbours,
          ),
        ),
      ],
    );
  }
}
