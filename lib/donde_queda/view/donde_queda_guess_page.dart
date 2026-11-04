import 'dart:async';

import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/donde_queda/cubit/donde_queda_guess_cubit.dart';
import 'package:ronda/donde_queda/widgets/close_button_row.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// ¿Dónde queda?: a member drops their one pin on this week's photo of
/// ronda [rondaId]. Works on web too: only taking the photo needs a phone.
class const DondeQuedaGuessPage({
  /// The ronda whose game this is.
  required final String rondaId,
  super.key,
}) extends StatelessWidget {
  /// The route, with the ronda's id in it.
  static const path = '/donde-queda/:rondaId';

  /// Where ronda [rondaId]'s guess screen is.
  static String location(String rondaId) =>
      '/donde-queda/${Uri.encodeComponent(rondaId)}';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = DondeQuedaGuessCubit(
          uid: context.read<AppBloc>().state.user.id,
          rondaId: rondaId,
          dondeQuedaRepository: context.read<DondeQuedaRepository>(),
        );
        unawaited(cubit.started());
        return cubit;
      },
      child: const DondeQuedaGuessView(),
    );
  }
}

/// The photo, the hint, the map and [Es acá].
class const DondeQuedaGuessView({super.key}) extends StatelessWidget {
  /// Maestro's handles.
  static const photoIdentifier = 'dondeQueda.guess.photo';
  static const mapIdentifier = 'dondeQueda.guess.map';
  static const confirmIdentifier = 'dondeQueda.guess.confirm';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<DondeQuedaGuessCubit>().state;
    final cubit = context.read<DondeQuedaGuessCubit>();
    List<Widget> closing(String message) => [
      Text(message, style: textTheme.bodyLarge),
      SizedBox(height: spacing.lg),
      const CloseButtonRow(),
    ];
    final children = switch ((state.status, state.game, state.photo)) {
      (DondeQuedaGuessStatus.loading, _, _) => [
        LoadingStatus(l10n.dondeQuedaLoading),
      ],
      (DondeQuedaGuessStatus.done, _, _) => closing(l10n.dondeQuedaGuessDone),
      (DondeQuedaGuessStatus.failure, _, _) => closing(
        l10n.dondeQuedaLoadError,
      ),
      (
        DondeQuedaGuessStatus.ready || DondeQuedaGuessStatus.sending,
        final game?,
        final photo?,
      ) =>
        [
          Semantics(
            identifier: photoIdentifier,
            label: l10n.dondeQuedaPhotoSemantics,
            image: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.memory(
                photo,
                excludeFromSemantics: true,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          if (game.hint.isNotEmpty) ...[
            SizedBox(height: spacing.sm),
            Text(l10n.dondeQuedaHint(game.hint), style: textTheme.titleMedium),
          ],
          SizedBox(height: spacing.md),
          Text(l10n.dondeQuedaGuessBody, style: textTheme.bodyLarge),
          SizedBox(height: spacing.sm),
          Semantics(
            identifier: mapIdentifier,
            child: BarrioMap(
              centre: (lat: game.centre.lat, lng: game.centre.lng),
              zoom: game.zoom,
              pin: switch (state.pin) {
                final pin? => (lat: pin.lat, lng: pin.lng),
                null => null,
              },
              attribution: l10n.dondeQuedaMapAttribution,
              semanticLabel: l10n.dondeQuedaMapSemantics,
              onTapped: (point) =>
                  cubit.pinDropped(MapPoint(point.lat, point.lng)),
            ),
          ),
          if (state.sendFailed) ...[
            SizedBox(height: spacing.sm),
            StatusLine(l10n.dondeQuedaGuessError),
          ],
          SizedBox(height: spacing.lg),
          MergeSemantics(
            child: Semantics(
              identifier: confirmIdentifier,
              child: FilledButton(
                onPressed:
                    state.pin == null ||
                        state.status == DondeQuedaGuessStatus.sending
                    ? null
                    : RondaHaptics.onCommit(cubit.confirmTapped),
                child: BusyLabel(
                  l10n.dondeQuedaConfirm,
                  busy: state.status == DondeQuedaGuessStatus.sending,
                ),
              ),
            ),
          ),
        ],
      _ => closing(l10n.dondeQuedaGuessClosed),
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dondeQuedaTitle)),
      body: SafeArea(
        top: false,
        child: ReadableColumn(
          child: ListView(
            padding: EdgeInsets.all(spacing.md),
            children: [
              RondaSwap(
                layoutBuilder: RondaSwap.topStartLayout,
                child: Column(
                  key: ValueKey(
                    state.status == DondeQuedaGuessStatus.sending
                        ? DondeQuedaGuessStatus.ready
                        : state.status,
                  ),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
