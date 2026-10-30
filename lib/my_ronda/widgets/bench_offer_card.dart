import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/cubit/bench_offer_cubit.dart';
import 'package:ronda/my_ronda/widgets/bench_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The offer of a freed seat on Mi ronda: "Se liberó un lugar", the meeting,
/// "¿Lo tomás?" with [Lo tomo] [Esta vez no] and the deadline; once taken,
/// "Vas esta vez" with where and when. Reads the [BenchOfferCubit] above; it
/// is the in-app path beside the notification's buttons.
class const BenchOfferCard({super.key}) extends StatelessWidget {
  /// Maestro's handles: the card and the buttons' prefix (`bench.yes`,
  /// `bench.no`).
  static const identifier = 'benchOffer';
  static const answerIdentifier = 'bench';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BenchOfferCubit>().state;
    final offer = state.offer;
    if (state.status != BenchOfferCardStatus.ready || offer == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<BenchOfferCubit>();
    final taken = offer.status == BenchOfferStatus.taken;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.md),
      child: Semantics(
        container: true,
        identifier: identifier,
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing.sm,
              children: [
                if (state.saving) const LinearProgressIndicator(),
                if (state.saveFailed)
                  NoteBanner(
                    variant: NoteBannerVariant.warning,
                    message: l10n.thisWeekSaveError,
                  ),
                if (state.over)
                  NoteBanner(
                    variant: NoteBannerVariant.warning,
                    message: l10n.benchOfferOver,
                  ),
                Semantics(
                  header: true,
                  child: Text(
                    taken ? l10n.benchOfferTakenTitle : l10n.benchOfferTitle,
                    style: textTheme.titleMedium,
                  ),
                ),
                Text(l10n.offerLine(offer), style: textTheme.bodyLarge),
                if (taken) ...[
                  if ((offer.placeName, offer.placeLandmark) case (
                    final place?,
                    final landmark?,
                  ))
                    Text(
                      l10n.thisWeekPlaceLandmark(place, landmark),
                      style: textTheme.bodyMedium,
                    ),
                  Text(l10n.benchOfferTakenBody, style: textTheme.bodyMedium),
                ] else ...[
                  RsvpBar(
                    identifier: answerIdentifier,
                    question: l10n.benchOfferAsk,
                    message: l10n.offerDeadline(offer),
                    yesLabel: l10n.benchOfferTake,
                    noLabel: l10n.benchOfferPass,
                    onYes: cubit.takeTapped,
                    onNo: cubit.passTapped,
                  ),
                  Text(l10n.benchOfferNoFines, style: textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
