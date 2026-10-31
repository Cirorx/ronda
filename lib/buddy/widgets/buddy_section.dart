import 'dart:async';

import 'package:contact_repository/contact_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/app/widgets/feedback.dart';
import 'package:ronda/buddy/cubit/buddy_cubit.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The buddy on Mi ronda, for ronda [rondaId]: the card that tells a buddy
/// someone missed a week, and, after the member's first meeting, "Si un día
/// faltás sin avisar, ¿a quién le avisamos?" or who they chose.
class const BuddySection({
  /// The member's ronda.
  required final String rondaId,

  /// The member.
  required final String uid,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(rondaId),
      create: (context) {
        final cubit = BuddyCubit(
          rondaId: rondaId,
          uid: uid,
          rondaRepository: context.read<RondaRepository>(),
          contactRepository: context.read<ContactRepository>(),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const BuddyView(),
    );
  }
}

/// The buddy card and the choice, from the [BuddyCubit] above. The card
/// and the choice each swap in on a [RondaSwap]; «Elegir» is a commit, felt
/// on the tap, and the choice it saved is shown and read out.
class const BuddyView({super.key}) extends StatelessWidget {
  /// Maestro's handles.
  static const writeIdentifier = 'buddy.write';
  static const askNotNowIdentifier = 'buddy.askNotNow';
  static String choiceIdentifier(String uid) => 'buddy.$uid';
  static const chooseIdentifier = 'buddy.choose';
  static const notNowIdentifier = 'buddy.notNow';
  static const changeIdentifier = 'buddy.change';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BuddyCubit>().state;
    final options = state.options;
    final ask = state.ask;
    final choice = switch (options) {
      BuddyOptions(due: true, chosen: false) => _Choose(state),
      BuddyOptions(due: true) when state.changing => _Choose(state),
      BuddyOptions(due: true, :final buddy) => _Chosen(buddy),
      _ => const SizedBox.shrink(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RondaSwap(
          layoutBuilder: topStartSwapLayout,
          child: ask == null
              ? const SizedBox.shrink(key: ValueKey('noAsk'))
              : _AskCard(ask, write: state.canWhatsApp, key: ValueKey(ask)),
        ),
        RondaSwap(
          layoutBuilder: topStartSwapLayout,
          child: KeyedSubtree(key: ValueKey(choice.runtimeType), child: choice),
        ),
      ],
    );
  }
}

class const _AskCard(final BuddyAsk ask, {required final bool write, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final cubit = context.read<BuddyCubit>();
    return Card(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.sm,
          children: [
            for (final miss in ask.misses)
              Text(
                l10n.buddyAskBody(miss.firstName, l10n.weekdayName(miss.dayId)),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.xs,
              children: [
                if (write)
                  MergeSemantics(
                    child: Semantics(
                      identifier: BuddyView.writeIdentifier,
                      child: FilledButton(
                        onPressed: cubit.writeTapped,
                        child: Text(l10n.buddyAskWrite),
                      ),
                    ),
                  ),
                MergeSemantics(
                  child: Semantics(
                    identifier: BuddyView.askNotNowIdentifier,
                    child: OutlinedButton(
                      onPressed: cubit.askClosed,
                      child: Text(l10n.buddyAskNotNow),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class const _Choose(final BuddyState state) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<BuddyCubit>();
    final choices = state.options!.choices;
    final choosing = state.saving == BuddySaving.choose;
    final passing = state.saving == BuddySaving.notNow;
    return Card(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.xs,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.buddyTitle, style: textTheme.titleSmall),
            ),
            Text(l10n.buddyBody, style: textTheme.bodyMedium),
            RadioGroup<String>(
              groupValue: state.selected,
              onChanged: (uid) => cubit.picked(uid!),
              child: Column(
                children: [
                  for (final choice in choices)
                    PressScale(
                      enabled: state.saving == null,
                      child: MergeSemantics(
                        child: Semantics(
                          identifier: BuddyView.choiceIdentifier(choice.uid),
                          child: RadioListTile<String>(
                            value: choice.uid,
                            title: Text(choice.firstName),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (state.saveFailed)
              NoteBanner(
                variant: NoteBannerVariant.warning,
                message: l10n.buddySaveError,
              ),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.xs,
              children: [
                MergeSemantics(
                  child: Semantics(
                    identifier: BuddyView.chooseIdentifier,
                    child: IgnorePointer(
                      ignoring: choosing,
                      child: FilledButton(
                        onPressed: switch (state.saving) {
                          null when state.selected != null =>
                            RondaHaptics.onCommit(cubit.chooseTapped),
                          BuddySaving.choose => () {},
                          _ => null,
                        },
                        child: BusyLabel(l10n.buddyChoose, busy: choosing),
                      ),
                    ),
                  ),
                ),
                MergeSemantics(
                  child: Semantics(
                    identifier: BuddyView.notNowIdentifier,
                    child: IgnorePointer(
                      ignoring: passing,
                      child: TextButton(
                        onPressed: switch (state.saving) {
                          null => cubit.notNowTapped,
                          BuddySaving.notNow => () {},
                          _ => null,
                        },
                        child: BusyLabel(l10n.buddyNotNow, busy: passing),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (state.saving != null) StatusLine(l10n.myRondaChoiceSaving),
          ],
        ),
      ),
    );
  }
}

class const _Chosen(final SetupMember? buddy) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      spacing: context.appSpacing.xs,
      children: [
        if (buddy != null)
          ExcludeSemantics(
            child: Icon(
              Icons.check_circle_outline,
              color: context.rondaPalette.yerba,
            ),
          ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(switch (buddy) {
              final buddy? => l10n.buddyChosen(buddy.firstName),
              null => l10n.buddyNobody,
            }, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
        MergeSemantics(
          child: Semantics(
            identifier: BuddyView.changeIdentifier,
            child: TextButton(
              onPressed: context.read<BuddyCubit>().changeTapped,
              child: Text(
                buddy == null ? l10n.buddyPickSomeone : l10n.buddyChange,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
