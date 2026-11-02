import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ronda/cuaderno/cubit/cuaderno_card_cubit.dart';
import 'package:ronda/cuaderno/cubit/cuaderno_hook.dart';
import 'package:ronda/cuaderno/view/cuaderno_page.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Mi ronda's way in to the cuaderno: the day's [CardHook], what the
/// cuaderno is for, and one button. It only waits to be tapped: nothing
/// pushes it, and it counts nothing.
class const CuadernoEntryCard({
  /// The day whose hook it shows; today when not given.
  final DateTime? today,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handle on [Abrir el cuaderno].
  static const identifier = 'cuaderno.entry';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                _hook(l10n, CardHook.on(today ?? DateTime.now())),
                style: textTheme.titleMedium,
              ),
            ),
            SizedBox(height: spacing.xs),
            Text(l10n.cuadernoEntryBody, style: textTheme.bodyMedium),
            SizedBox(height: spacing.sm),
            MergeSemantics(
              child: Semantics(
                identifier: identifier,
                child: OutlinedButton(
                  onPressed: () => context.push(CuadernoPage.path),
                  child: Text(l10n.cuadernoOpen),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _hook(AppLocalizations l10n, CardHook hook) => switch (hook) {
  CardHook.sunset => l10n.cuadernoCardHookSunset,
  CardHook.bizcochos => l10n.cuadernoCardHookBizcochos,
  CardHook.postcard => l10n.cuadernoCardHookPostcard,
  CardHook.corner => l10n.cuadernoCardHookCorner,
  CardHook.learned => l10n.cuadernoCardHookLearned,
  CardHook.talk => l10n.cuadernoCardHookTalk,
  CardHook.bring => l10n.cuadernoCardHookBring,
};

/// The line the member chose to bring, as a reminder on their own card;
/// nothing when none is chosen. Read from the phone's cuaderno only.
class const BringReminder({super.key}) extends StatelessWidget {
  /// Maestro's handle on the reminder.
  static const identifier = 'cuaderno.reminder';

  @override
  Widget build(BuildContext context) {
    final line = context.watch<CuadernoCardCubit>().state;
    if (line == null) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      identifier: identifier,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: context.appSpacing.xs,
        children: [
          const ExcludeSemantics(child: Icon(Icons.menu_book_outlined)),
          Expanded(
            child: Text(
              context.l10n.cuadernoBringReminder(line),
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
