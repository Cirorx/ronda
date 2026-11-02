import 'package:ronda/first_visit/widgets/first_visit_labels.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Así va a ser": what a newcomer reads before their first meeting. Who
/// waits and how to recognise them, the place and its landmark, "Los
/// primeros cinco minutos" and "¿Te querés ir antes?". The host's sheet
/// draws the same words as its preview, from what it is about to save.
class const AsiVaASer({
  /// Who waits, by first name; `null` while nobody does.
  final String? waiterName,

  /// How to recognise them, in the host's words ("tiene el termo verde").
  final String? sign,

  /// The public place's name.
  final String? placeName,

  /// How to find it.
  final String? placeLandmark,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handle on "Te espera Jorge", on the newcomer's card.
  static const waiterIdentifier = 'firstVisit.waiter';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.xs,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.firstVisitTitle, style: textTheme.titleMedium),
        ),
        if (l10n.waiterLine(waiterName, sign) case final line?)
          // Merged, so the node Maestro finds by its identifier carries the
          // words too.
          MergeSemantics(
            child: Semantics(
              identifier: waiterIdentifier,
              child: Text(line, style: textTheme.bodyLarge),
            ),
          ),
        switch (placeName) {
          final place? => Text(
            l10n.firstVisitPlace(place),
            style: textTheme.bodyLarge,
          ),
          null => Text(l10n.firstVisitNoPlace, style: textTheme.bodyMedium),
        },
        if (placeLandmark case final landmark? when placeName != null)
          Text(l10n.firstVisitLandmark(landmark), style: textTheme.bodyMedium),
        SizedBox(height: spacing.xxs),
        Semantics(
          header: true,
          child: Text(
            l10n.firstVisitFirstMinutesTitle,
            style: textTheme.titleSmall,
          ),
        ),
        Text(switch (waiterName) {
          final name? => l10n.firstVisitFirstMinutesWaiter(name),
          null => l10n.firstVisitFirstMinutes,
        }, style: textTheme.bodyMedium),
        Text(l10n.firstVisitLeave, style: textTheme.bodyMedium),
      ],
    );
  }
}
