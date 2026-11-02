import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/first_visit/cubit/first_visit_cubit.dart';
import 'package:ronda/first_visit/widgets/asi_va_a_ser.dart';
import 'package:ronda/first_visit/widgets/first_visit_labels.dart';
import 'package:ronda/first_visit/widgets/welcome_sheet.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Así va a ser on Mi ronda (#70), under the week's card, for member [uid]:
/// their own card before their first meeting, the hosts' "¿Quién espera a
/// Nico?", and "No puedo" for a member a host picked. Nothing when none
/// applies. No push comes with any of it.
class const FirstVisitSection({
  /// The member.
  required final String uid,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FirstVisitCubit(
        uid: uid,
        rondaRepository: context.read<RondaRepository>(),
      )..subscribe(),
      child: FirstVisitView(uid: uid),
    );
  }
}

/// The cards of the [FirstVisitCubit] above, each swapping in on a
/// [RondaSwap].
class const FirstVisitView({required final String uid, super.key})
    extends StatelessWidget {
  /// Maestro's handles on the cards and their buttons.
  static const cardIdentifier = 'firstVisit';
  static String chooseIdentifier(String newcomerUid) =>
      'welcome.choose.$newcomerUid';
  static String declineIdentifier(String newcomerUid) =>
      'welcome.decline.$newcomerUid';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FirstVisitCubit>().state;
    final cards = <Widget>[
      if (state.card case final welcome?)
        Semantics(
          key: ValueKey(('card', welcome.newcomerUid)),
          container: true,
          identifier: cardIdentifier,
          child: _Paper(
            AsiVaASer(
              waiterName: welcome.waiter?.firstName,
              sign: welcome.sign,
              placeName: welcome.placeName,
              placeLandmark: welcome.placeLandmark,
            ),
          ),
        ),
      for (final welcome in state.toChoose)
        _Paper(
          _HostAsk(welcome: welcome, uid: uid),
          key: ValueKey(('host', welcome.newcomerUid)),
        ),
      for (final welcome in state.waitingFor)
        _Paper(
          _WaiterAsk(welcome: welcome, state: state),
          key: ValueKey(('waiter', welcome.newcomerUid)),
        ),
    ];
    return RondaSwap(
      layoutBuilder: RondaSwap.topStartLayout,
      child: cards.isEmpty
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Column(
              key: const ValueKey('cards'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cards,
            ),
    );
  }
}

class const _Paper(final Widget child, {super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(context.appSpacing.md),
      child: child,
    ),
  );
}

/// "Viene alguien nuevo": the question to the ronda's anfitrión and cola,
/// who waits now, and [Elegir quién espera] or [Cambiar].
class const _HostAsk({
  required final Welcome welcome,
  required final String uid,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.xs,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.welcomeAskTitle, style: textTheme.titleSmall),
        ),
        Text(l10n.welcomeQuestion(welcome), style: textTheme.bodyLarge),
        Text(
          l10n.welcomeWaiterLine(welcome, uid: uid),
          style: textTheme.bodyMedium,
        ),
        if (welcome.sign case final sign? when welcome.picked)
          Text(
            l10n.welcomeAskSign(welcome.newcomerName, sign),
            style: textTheme.bodyMedium,
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MergeSemantics(
            child: Semantics(
              identifier: FirstVisitView.chooseIdentifier(welcome.newcomerUid),
              child: OutlinedButton(
                onPressed: () => unawaited(
                  WelcomeSheet.show(context, uid: uid, welcome: welcome),
                ),
                child: Text(
                  welcome.picked
                      ? l10n.welcomeAskChange
                      : l10n.welcomeAskChoose,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Esperás a alguien nuevo": to the member a host picked, with when to be
/// there, the line Nico will recognise them by, and [No puedo], a commit
/// felt on the tap.
class const _WaiterAsk({
  required final Welcome welcome,
  required final FirstVisitState state,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final saving = state.save == WelcomeSaveStatus.saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.xs,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.waiterAskTitle, style: textTheme.titleSmall),
        ),
        Text(
          l10n.waiterAskBody(
            welcome.setBy?.firstName ?? '',
            welcome.newcomerName,
            l10n.weekdayName(weekdayId(welcome.date)),
          ),
          style: textTheme.bodyLarge,
        ),
        if (arrivalTime(welcome.hour) case final time?)
          Text(l10n.waiterAskAt(time), style: textTheme.bodyMedium),
        if (welcome.sign case final sign?)
          Text(
            l10n.waiterAskSign(welcome.newcomerName, sign),
            style: textTheme.bodyMedium,
          ),
        if (state.failure case final reason?
            when state.save == WelcomeSaveStatus.failed)
          NoteBanner(
            variant: NoteBannerVariant.warning,
            message: l10n.welcomeFailure(reason),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MergeSemantics(
            child: Semantics(
              identifier: FirstVisitView.declineIdentifier(welcome.newcomerUid),
              child: OutlinedButton(
                onPressed: saving
                    ? null
                    : RondaHaptics.onCommit(
                        () => context.read<FirstVisitCubit>().declined(welcome),
                      ),
                child: Text(l10n.waiterAskNo),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
