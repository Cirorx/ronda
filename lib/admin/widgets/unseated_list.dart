import 'package:ronda/admin/widgets/admin_labels.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Who a proposal leaves without a ronda: how many, then each by first
/// name, barrio and the slots they picked (a proposal written before names
/// were kept shows the count only).
class const UnseatedList({required final Proposal proposal, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final people = proposal.unseated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminUnseated(proposal.unseatedCount),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        for (final (index, person) in people.indexed)
          PersonRow(
            initial: person.firstName.characters.firstOrNull ?? '?',
            name: person.firstName,
            detail: l10n.adminUnseatedDetail(
              l10n.barrioOf(person.barrioId),
              l10n.slotsOf(person.slotIds),
            ),
            showDivider: index < people.length - 1,
          ),
      ],
    );
  }
}
