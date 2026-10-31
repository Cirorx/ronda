import 'dart:async';
import 'dart:typed_data';

import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/donde_queda/cubit/donde_queda_photo_cubit.dart';
import 'package:ronda/donde_queda/models/game_text.dart';
import 'package:ronda/donde_queda/widgets/close_button_row.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// ¿Dónde queda?: the member whose turn it is takes this week's photo for
/// ronda [rondaId] (`docs/PRODUCT.md` § The weekly loop).
class const DondeQuedaPhotoPage({
  /// The ronda whose game this is.
  required final String rondaId,
  super.key,
}) extends StatelessWidget {
  /// The route, with the ronda's id in it.
  static const path = '/donde-queda/:rondaId/foto';

  /// Where ronda [rondaId]'s photo screen is.
  static String location(String rondaId) =>
      '/donde-queda/${Uri.encodeComponent(rondaId)}/foto';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = DondeQuedaPhotoCubit(
          uid: context.read<AppBloc>().state.user.id,
          rondaId: rondaId,
          dondeQuedaRepository: context.read<DondeQuedaRepository>(),
        );
        unawaited(cubit.started());
        return cubit;
      },
      child: const DondeQuedaPhotoView(),
    );
  }
}

/// The photo's steps, each swapped in for the last on a [RondaSwap]:
/// the camera, the blurred photo with its words, the map, the check.
class const DondeQuedaPhotoView({super.key}) extends StatelessWidget {
  /// Maestro's handles.
  static const takePhotoIdentifier = 'dondeQueda.photo.take';
  static const pickPhotoIdentifier = 'dondeQueda.photo.pick';
  static const photoIdentifier = 'dondeQueda.photo.photo';
  static const lineIdentifier = 'dondeQueda.photo.line';
  static const hintIdentifier = 'dondeQueda.photo.hint';
  static const nextIdentifier = 'dondeQueda.photo.next';
  static const retakeIdentifier = 'dondeQueda.photo.retake';
  static const mapIdentifier = 'dondeQueda.photo.map';
  static const sendIdentifier = 'dondeQueda.photo.send';
  static const backIdentifier = 'dondeQueda.photo.back';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final state = context.watch<DondeQuedaPhotoCubit>().state;
    final step = switch ((state.status, state.photo)) {
      (DondeQuedaPhotoStatus.blurring, _?) => DondeQuedaPhotoStatus.preview,
      (final status, _) => status,
    };
    final children = switch (step) {
      DondeQuedaPhotoStatus.loading => [LoadingStatus(l10n.dondeQuedaLoading)],
      DondeQuedaPhotoStatus.closed => _closing(context, l10n.dondeQuedaClosed),
      DondeQuedaPhotoStatus.unsupported => _webOnly(context),
      DondeQuedaPhotoStatus.choosing => _choosing(context),
      DondeQuedaPhotoStatus.blurring => [LoadingStatus(l10n.mateFlyerBlurring)],
      DondeQuedaPhotoStatus.preview => _preview(context, state),
      DondeQuedaPhotoStatus.pinning => _pinning(context, state),
      DondeQuedaPhotoStatus.sending => [LoadingStatus(l10n.dondeQuedaSending)],
      DondeQuedaPhotoStatus.done => _closing(context, l10n.dondeQuedaDone),
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dondeQuedaTitle)),
      body: ReadableColumn(
        child: ListView(
          padding: EdgeInsets.all(spacing.md),
          children: [
            if (_failureMessage(context, state.failure) case final message?)
              Padding(
                padding: EdgeInsets.only(bottom: spacing.md),
                child: Semantics(
                  liveRegion: true,
                  child: NoteBanner(
                    message: message,
                    variant: NoteBannerVariant.warning,
                  ),
                ),
              ),
            RondaSwap(
              layoutBuilder: RondaSwap.topStartLayout,
              child: Column(
                key: ValueKey(step),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _failureMessage(
    BuildContext context,
    DondeQuedaPhotoFailure? failure,
  ) {
    final l10n = context.l10n;
    return switch (failure) {
      null => null,
      DondeQuedaPhotoFailure.photo => l10n.mateFlyerPhotoError,
      DondeQuedaPhotoFailure.houseNumber => l10n.dondeQuedaRefusedHouseNumber,
      DondeQuedaPhotoFailure.person => l10n.dondeQuedaRefusedPerson,
      DondeQuedaPhotoFailure.empty => l10n.dondeQuedaRefusedEmpty,
      DondeQuedaPhotoFailure.words => l10n.dondeQuedaRefusedWords,
      DondeQuedaPhotoFailure.send => l10n.dondeQuedaSendError,
    };
  }

  static Widget _action(String identifier, Widget button) => MergeSemantics(
    child: Semantics(identifier: identifier, child: button),
  );

  List<Widget> _closing(BuildContext context, String message) => [
    Text(message, style: Theme.of(context).textTheme.bodyLarge),
    SizedBox(height: context.appSpacing.lg),
    const CloseButtonRow(),
  ];

  List<Widget> _webOnly(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return [
      Icon(
        Icons.phone_android,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
      SizedBox(height: context.appSpacing.md),
      Text(l10n.mateFlyerWebOnly, style: textTheme.headlineSmall),
      SizedBox(height: context.appSpacing.xs),
      Text(l10n.mateFlyerWebOnlyBody, style: textTheme.bodyLarge),
    ];
  }

  List<Widget> _choosing(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<DondeQuedaPhotoCubit>();
    return [
      Text(l10n.dondeQuedaPrompt, style: textTheme.headlineSmall),
      SizedBox(height: spacing.xs),
      Text(l10n.dondeQuedaNoPeople, style: textTheme.bodyLarge),
      SizedBox(height: spacing.lg),
      _action(
        takePhotoIdentifier,
        FilledButton.icon(
          onPressed: () => cubit.photoRequested(PhotoSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(l10n.mateFlyerTakePhoto),
        ),
      ),
      SizedBox(height: spacing.sm),
      _action(
        pickPhotoIdentifier,
        OutlinedButton.icon(
          onPressed: () => cubit.photoRequested(PhotoSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(l10n.mateFlyerPickPhoto),
        ),
      ),
    ];
  }

  List<Widget> _preview(BuildContext context, DondeQuedaPhotoState state) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<DondeQuedaPhotoCubit>();
    final photo = state.photo!;
    final busy = state.status != DondeQuedaPhotoStatus.preview;
    String? error(GameText text) => text.isPure
        ? null
        : switch (text.error) {
            GameTextError.empty => l10n.dondeQuedaLineEmpty,
            GameTextError.tooLong => l10n.dondeQuedaTooLong,
            null => null,
          };
    return [
      Text(l10n.mateFlyerPreviewTitle, style: textTheme.headlineSmall),
      SizedBox(height: spacing.xs),
      Text(
        '${l10n.mateFlyerBlurredFaces(photo.blurredFaces)} '
        '${l10n.mateFlyerTapToBlur}.',
        style: textTheme.bodyLarge,
      ),
      SizedBox(height: spacing.md),
      Semantics(
        identifier: photoIdentifier,
        label: l10n.mateFlyerPhotoSemantics,
        hint: l10n.mateFlyerTapToBlur,
        image: true,
        child: AspectRatio(
          aspectRatio: photo.width / photo.height,
          child: TapToBlurPhoto(
            image: _bytesImage(photo.jpeg),
            busy: busy,
            onTapped: (x, y) => cubit.faceTapped(x: x, y: y),
          ),
        ),
      ),
      if (busy) ...[
        SizedBox(height: spacing.xs),
        StatusLine(l10n.mateFlyerBlurringTapped),
      ],
      SizedBox(height: spacing.lg),
      Semantics(
        identifier: lineIdentifier,
        child: TextFormField(
          initialValue: state.line.value,
          maxLength: GameText.maxLength,
          decoration: InputDecoration(
            labelText: l10n.dondeQuedaLineLabel,
            helperText: l10n.dondeQuedaLineHelper,
            helperMaxLines: 3,
            errorText: error(state.line),
          ),
          onChanged: cubit.lineChanged,
        ),
      ),
      SizedBox(height: spacing.sm),
      Semantics(
        identifier: hintIdentifier,
        child: TextFormField(
          initialValue: state.hint.value,
          maxLength: GameText.maxLength,
          decoration: InputDecoration(
            labelText: l10n.dondeQuedaHintLabel,
            helperText: l10n.dondeQuedaHintHelper,
            helperMaxLines: 3,
            errorText: error(state.hint),
          ),
          onChanged: cubit.hintChanged,
        ),
      ),
      SizedBox(height: spacing.lg),
      _action(
        nextIdentifier,
        FilledButton(
          onPressed: busy ? null : cubit.wordsDone,
          child: Text(l10n.dondeQuedaNext),
        ),
      ),
      SizedBox(height: spacing.sm),
      _action(
        retakeIdentifier,
        OutlinedButton(
          onPressed: busy ? null : cubit.retakeRequested,
          child: Text(l10n.mateFlyerRetake),
        ),
      ),
    ];
  }

  List<Widget> _pinning(BuildContext context, DondeQuedaPhotoState state) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<DondeQuedaPhotoCubit>();
    final game = state.game!;
    final pin = state.pin;
    return [
      Text(l10n.dondeQuedaPinTitle, style: textTheme.headlineSmall),
      SizedBox(height: spacing.xs),
      Text(l10n.dondeQuedaPinBody, style: textTheme.bodyLarge),
      SizedBox(height: spacing.md),
      Semantics(
        identifier: mapIdentifier,
        child: BarrioMap(
          centre: (lat: game.centre.lat, lng: game.centre.lng),
          zoom: game.zoom,
          pin: pin == null ? null : (lat: pin.lat, lng: pin.lng),
          attribution: l10n.dondeQuedaMapAttribution,
          semanticLabel: l10n.dondeQuedaMapSemantics,
          onTapped: (point) => cubit.pinDropped(MapPoint(point.lat, point.lng)),
        ),
      ),
      SizedBox(height: spacing.lg),
      _action(
        sendIdentifier,
        FilledButton(
          onPressed: pin == null
              ? null
              : RondaHaptics.onCommit(cubit.sendTapped),
          child: Text(l10n.dondeQuedaSend),
        ),
      ),
      SizedBox(height: spacing.sm),
      _action(
        backIdentifier,
        OutlinedButton(
          onPressed: cubit.backToWords,
          child: Text(l10n.dondeQuedaBack),
        ),
      ),
    ];
  }

  /// A JPEG from memory; a broken one leaves an empty space rather than an
  /// error.
  static Widget _bytesImage(Uint8List bytes) => Image.memory(
    bytes,
    fit: BoxFit.fill,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}
