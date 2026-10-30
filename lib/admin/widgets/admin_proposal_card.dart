import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/admin/widgets/add_to_ronda_sheet.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/widgets/onboarding_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// One proposed ronda for the admin: what, where and when, its members
/// (first name, age band, walk) and the checks it passes or breaks. Once
/// approved, "Sumar a esta ronda" opens the [AddToRondaSheet].
class const AdminProposalCard({required final ProposedRonda ronda, super.key})
    extends StatelessWidget {
  /// Maestro's handle on "Sumar a esta ronda".
  static const addIdentifier = 'admin_add_to_ronda';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final pretext = Pretext.fromId(ronda.pretextId);
    final barrio = Barrio.fromId(ronda.barrioId);
    final slot = Slot.fromId(ronda.slotId);

    return Card(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adminRondaTitle(
                pretext == null ? ronda.pretextId : l10n.pretext(pretext),
                barrio == null ? ronda.barrioId : l10n.barrio(barrio),
              ),
              style: theme.textTheme.titleMedium,
            ),
            Text(
              slot == null ? ronda.slotId : l10n.slot(slot),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacing.sm),
            for (final (index, member) in ronda.members.indexed)
              PersonRow(
                initial: member.firstName.characters.first,
                name: member.firstName,
                detail: _memberDetail(l10n, member),
                showDivider: index < ronda.members.length - 1,
              ),
            SizedBox(height: spacing.sm),
            for (final (kept, label) in _checks(l10n))
              _Check(kept: kept, label: label),
            if (ronda.rondaId case final rondaId?) ...[
              SizedBox(height: spacing.xs),
              MergeSemantics(
                child: Semantics(
                  identifier: addIdentifier,
                  child: OutlinedButton(
                    onPressed: () => AddToRondaSheet.show(
                      context,
                      rondaId: rondaId,
                      rondaRepository: context.read<RondaRepository>(),
                    ),
                    child: Text(l10n.adminAddToRonda),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _ageGroup(AppLocalizations l10n, AgeGroup group) =>
      switch (group) {
        AgeGroup.under30 => l10n.adminAgeGroupUnder30,
        AgeGroup.from30To59 => l10n.adminAgeGroupFrom30To59,
        AgeGroup.sixtyPlus => l10n.adminAgeGroupSixtyPlus,
      };

  static String _memberDetail(AppLocalizations l10n, ProposedMember member) {
    final band = AgeBand.fromId(member.ageBandId);
    return l10n.adminMemberDetail(
      band == null ? member.ageBandId : l10n.ageBand(band),
      member.distanceBlocks.round(),
    );
  }

  /// The checks the approval copy names, each with whether it holds: the
  /// walk, "nadie es el único de su edad" for every age group the solver
  /// compares (always, with how many are in it), and one +1 line per member
  /// whose +1 signed up.
  List<(bool, String)> _checks(AppLocalizations l10n) => [
    if (ronda.allWithinTenBlocks)
      (true, l10n.adminCheckWithinTen)
    else
      (false, l10n.adminCheckFarther),
    for (final check in ronda.ageChecks)
      if (check.kept)
        (
          true,
          l10n.adminCheckAgeKept(_ageGroup(l10n, check.group), check.count),
        )
      else
        (
          false,
          l10n.adminCheckAgeAlone(
            _ageGroup(l10n, check.group),
            check.firstNames.single,
          ),
        ),
    for (final member in ronda.members)
      if (member.plusOneInGroup == true)
        (true, l10n.adminCheckPlusOneTogether(member.firstName))
      else if (member.plusOneInGroup == false)
        (false, l10n.adminCheckPlusOneApart(member.firstName)),
  ];
}

/// One check line: a mark and the sentence, read as "Se cumple: …".
class const _Check({required final bool kept, required final String label})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    return Semantics(
      container: true,
      label: '${kept ? l10n.adminCheckKept : l10n.adminCheckBroken}: $label',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsetsDirectional.only(bottom: spacing.xxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              kept ? Icons.check : Icons.close,
              color: kept
                  ? context.rondaPalette.yerba
                  : theme.colorScheme.error,
            ),
            SizedBox(width: spacing.xs),
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}
