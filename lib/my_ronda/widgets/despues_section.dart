import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda/my_ronda/widgets/despues_sheet.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The después on the Mi ronda card: "Después, si querés: …" once it is
/// set; for this week's host, where it stands and "¿Hay después esta
/// semana?"; for the member whose home it would be, the question first.
/// Nothing for a member while there is none.
class const DespuesSection({
  /// The week it belongs to.
  required final ThisWeek week,

  /// The member reading the card.
  required final String uid,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handles: the host's button and the home's two answers.
  static const setIdentifier = 'despues.set';
  static const homeYesIdentifier = 'despues.homeYes';
  static const homeNoIdentifier = 'despues.homeNo';

  bool get _hosts =>
      uid == week.anfitrion?.uid ||
      uid == week.cola?.uid ||
      uid == week.opener?.uid;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final despues = week.despues;
    final state = context.watch<ThisWeekCubit>().state;
    final cubit = context.read<ThisWeekCubit>();
    final mine = despues?.setBy.uid == uid;
    final askedMe =
        despues?.status == DespuesStatus.asking &&
        despues?.homeOf?.uid == uid &&
        !mine;

    final lines = <Widget>[
      if (l10n.despuesLine(despues) case final line?)
        Text(line, style: textTheme.bodyLarge),
      if (_hosts) ...[
        if (despues case Despues(
          kind: DespuesKind.none,
          status: DespuesStatus.set,
        ))
          Text(l10n.despuesNone, style: textTheme.bodyMedium),
        if (despues case Despues(status: DespuesStatus.asking, :final homeOf?)
            when mine)
          Text(
            l10n.despuesAsking(homeOf.firstName),
            style: textTheme.bodyMedium,
          ),
        if (despues case Despues(status: DespuesStatus.declined, :final homeOf?)
            when mine)
          Text(
            l10n.despuesDeclined(homeOf.firstName),
            style: textTheme.bodyMedium,
          ),
      ],
      if (despues case Despues(:final setBy, :final what?, :final address?)
          when askedMe) ...[
        Text(
          l10n.despuesHomeQuestion(setBy.firstName, what, address),
          style: textTheme.bodyLarge,
        ),
        if (state.actionFailure != null)
          NoteBanner(
            variant: NoteBannerVariant.warning,
            message: l10n.weekActionError,
          ),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.xs,
          children: [
            MergeSemantics(
              child: Semantics(
                identifier: homeYesIdentifier,
                child: FilledButton(
                  onPressed: state.acting
                      ? null
                      : () => cubit.homeAnswered(yes: true),
                  child: Text(l10n.despuesHomeYes),
                ),
              ),
            ),
            MergeSemantics(
              child: Semantics(
                identifier: homeNoIdentifier,
                child: OutlinedButton(
                  onPressed: state.acting
                      ? null
                      : () => cubit.homeAnswered(yes: false),
                  child: Text(l10n.despuesHomeNo),
                ),
              ),
            ),
          ],
        ),
      ],
      if (_hosts && week.week != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MergeSemantics(
            child: Semantics(
              identifier: setIdentifier,
              child: TextButton(
                onPressed: () =>
                    DespuesSheet.show(context, uid: uid, week: week),
                child: Text(
                  despues == null ? l10n.despuesSet : l10n.despuesChange,
                ),
              ),
            ),
          ),
        ),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.xxs,
      children: lines,
    );
  }
}
