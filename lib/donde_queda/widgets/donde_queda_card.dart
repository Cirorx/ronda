import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ronda/donde_queda/cubit/donde_queda_cubit.dart';
import 'package:ronda/donde_queda/view/donde_queda_guess_page.dart';
import 'package:ronda/donde_queda/view/donde_queda_photo_page.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// ¿Dónde queda? on Mi ronda, for ronda [rondaId]: last week's answer
/// ("Era la puerta verde de Gestido y Rivera." "Cerca: 3 de 5"), and this
/// week's game as [uid] sees it: their turn to take the photo, a photo to
/// guess, or that they already did. Shows nothing while there is neither.
class const DondeQuedaCard({
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
      create: (context) => DondeQuedaCubit(
        rondaId: rondaId,
        uid: uid,
        dondeQuedaRepository: context.read<DondeQuedaRepository>(),
      )..subscribe(),
      child: DondeQuedaView(rondaId: rondaId),
    );
  }
}

/// The card's content, from the [DondeQuedaCubit] above.
class const DondeQuedaView({
  /// The member's ronda, for the photo and the guess screens.
  required final String rondaId,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handles.
  static const takePhotoIdentifier = 'dondeQueda.takePhoto';
  static const skipIdentifier = 'dondeQueda.skip';
  static const guessIdentifier = 'dondeQueda.guess';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<DondeQuedaCubit>().state;
    final reveal = state.week?.reveal;
    final game = state.week?.game;
    final turn = _turn(context, game, state);
    if (reveal == null && turn == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.xs,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.dondeQuedaTitle, style: textTheme.titleMedium),
            ),
            if (reveal != null) ...[
              Text(l10n.dondeQuedaRevealLead, style: textTheme.labelLarge),
              Text(
                l10n.dondeQuedaReveal(reveal.line),
                style: textTheme.bodyLarge,
              ),
              Text(
                reveal.guessed == 0
                    ? l10n.dondeQuedaNobodyGuessed
                    : l10n.dondeQuedaClose(reveal.close, reveal.guessed),
                style: textTheme.bodyMedium,
              ),
              if (turn != null) const Divider(),
            ],
            ?turn,
          ],
        ),
      ),
    );
  }

  Widget? _turn(
    BuildContext context,
    DondeQuedaGame? game,
    DondeQuedaState state,
  ) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    Widget line(String text) => Text(text, style: textTheme.bodyLarge);
    Widget action(String identifier, Widget button) => MergeSemantics(
      child: Semantics(identifier: identifier, child: button),
    );
    return switch (game) {
      DondeQuedaGame(isMyTurn: true) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.xs,
        children: [
          line(l10n.dondeQuedaYourTurn),
          line(l10n.dondeQuedaPrompt),
          Text(l10n.dondeQuedaHowItWorks, style: textTheme.bodyMedium),
          if (state.passFailed) StatusLine(l10n.dondeQuedaSkipError),
          SizedBox(height: spacing.xxs),
          action(
            takePhotoIdentifier,
            FilledButton.icon(
              onPressed: state.passing
                  ? null
                  : () => context.push(DondeQuedaPhotoPage.location(rondaId)),
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l10n.dondeQuedaTakePhoto),
            ),
          ),
          action(
            skipIdentifier,
            OutlinedButton(
              onPressed: state.passing
                  ? null
                  : context.read<DondeQuedaCubit>().passTapped,
              child: BusyLabel(l10n.dondeQuedaSkip, busy: state.passing),
            ),
          ),
        ],
      ),
      DondeQuedaGame(status: DondeQuedaStatus.open, posted: true) => line(
        l10n.dondeQuedaPosted,
      ),
      DondeQuedaGame(status: DondeQuedaStatus.open, guessed: true) => line(
        l10n.dondeQuedaGuessed,
      ),
      DondeQuedaGame(status: DondeQuedaStatus.open) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.sm,
        children: [
          line(l10n.dondeQuedaNew),
          action(
            guessIdentifier,
            FilledButton.icon(
              onPressed: () =>
                  context.push(DondeQuedaGuessPage.location(rondaId)),
              icon: const Icon(Icons.place_outlined),
              label: Text(l10n.dondeQuedaGuess),
            ),
          ),
        ],
      ),
      _ => null,
    };
  }
}
