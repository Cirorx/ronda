import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flyer_repository/flyer_repository.dart';
import 'package:ronda/app/widgets/feedback.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/mate_flyer/cubit/mate_flyer_cubit.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The flyer's steps: the photo, the blurred preview, the wait, the flyer,
/// each swapped in for the last on a [RondaSwap]. Making the flyer and
/// sharing it are commits, felt on the tap.
class const MateFlyerView({super.key}) extends StatelessWidget {
  /// Maestro's handles.
  static const takePhotoIdentifier = 'mateFlyer.takePhoto';
  static const pickPhotoIdentifier = 'mateFlyer.pickPhoto';
  static const photoIdentifier = 'mateFlyer.photo';
  static const makeIdentifier = 'mateFlyer.make';
  static const retakeIdentifier = 'mateFlyer.retake';
  static const shareIdentifier = 'mateFlyer.share';
  static const flyerIdentifier = 'mateFlyer.flyer';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<MateFlyerCubit>().state;
    final spacing = context.appSpacing;
    final (step, children) = switch ((state.status, state.photo, state.flyer)) {
      (MateFlyerStatus.unsupported, _, _) => (
        MateFlyerStatus.unsupported,
        _webOnly(context),
      ),
      (MateFlyerStatus.choosing, _, _) => (
        MateFlyerStatus.choosing,
        _choosing(context),
      ),
      (MateFlyerStatus.blurring || MateFlyerStatus.preview, final photo?, _) =>
        (
          MateFlyerStatus.preview,
          _preview(
            context,
            photo,
            busy: state.status != MateFlyerStatus.preview,
          ),
        ),
      (MateFlyerStatus.blurring, null, _) => (
        MateFlyerStatus.blurring,
        _working(context, l10n.mateFlyerBlurring),
      ),
      (MateFlyerStatus.making, _, _) => (
        MateFlyerStatus.making,
        _working(context, l10n.mateFlyerMaking),
      ),
      (MateFlyerStatus.ready, _, final flyer?) => (
        MateFlyerStatus.ready,
        _ready(context, flyer),
      ),
      _ => (MateFlyerStatus.choosing, _choosing(context)),
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mateFlyerTitle)),
      body: ListView(
        padding: EdgeInsets.all(spacing.md),
        children: [
          if (_failureMessage(context, state.failure) case final message?) ...[
            Semantics(
              liveRegion: true,
              child: NoteBanner(
                message: message,
                variant: NoteBannerVariant.warning,
              ),
            ),
            SizedBox(height: spacing.md),
          ],
          RondaSwap(
            layoutBuilder: topStartSwapLayout,
            child: Column(
              key: ValueKey(step),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  String? _failureMessage(BuildContext context, MateFlyerFailure? failure) {
    final l10n = context.l10n;
    return switch (failure) {
      null => null,
      MateFlyerFailure.photo => l10n.mateFlyerPhotoError,
      MateFlyerFailure.notHost => l10n.mateFlyerNotHost,
      MateFlyerFailure.nothingToCutOut => l10n.mateFlyerNothingFound,
      MateFlyerFailure.flyer => l10n.mateFlyerError,
      MateFlyerFailure.share => l10n.mateFlyerShareError,
    };
  }

  static Widget _action(String identifier, Widget button) => MergeSemantics(
    child: Semantics(identifier: identifier, child: button),
  );

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
    final cubit = context.read<MateFlyerCubit>();
    return [
      Text(l10n.mateFlyerIntro, style: Theme.of(context).textTheme.bodyLarge),
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

  List<Widget> _working(BuildContext context, String message) {
    return [
      SizedBox(height: context.appSpacing.xlg),
      const Center(child: CircularProgressIndicator()),
      SizedBox(height: context.appSpacing.md),
      Semantics(
        liveRegion: true,
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    ];
  }

  List<Widget> _preview(
    BuildContext context,
    BlurredPhoto photo, {
    required bool busy,
  }) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<MateFlyerCubit>();
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
          child: _TapToBlur(
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
      _action(
        makeIdentifier,
        FilledButton(
          onPressed: busy ? null : RondaHaptics.onCommit(cubit.flyerRequested),
          child: Text(l10n.mateFlyerMake),
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

  List<Widget> _ready(BuildContext context, MateFlyer flyer) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<MateFlyerCubit>();
    return [
      Text(l10n.mateFlyerReadyTitle, style: textTheme.headlineSmall),
      SizedBox(height: spacing.md),
      Semantics(
        identifier: flyerIdentifier,
        label: l10n.mateFlyerImageSemantics,
        image: true,
        child: ExcludeSemantics(child: _bytesImage(flyer.image)),
      ),
      SizedBox(height: spacing.sm),
      Text(l10n.mateFlyerPhotoUse, style: textTheme.bodyMedium),
      SizedBox(height: spacing.lg),
      _action(
        shareIdentifier,
        FilledButton.icon(
          onPressed: RondaHaptics.onCommit(
            () => cubit.shareRequested(title: l10n.mateFlyerTitle),
          ),
          icon: const Icon(Icons.ios_share),
          label: Text(l10n.mateFlyerShare),
        ),
      ),
      SizedBox(height: spacing.sm),
      _action(
        retakeIdentifier,
        OutlinedButton(
          onPressed: cubit.retakeRequested,
          child: Text(l10n.mateFlyerRetake),
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

/// {@template tap_to_blur}
/// The blurred photo, where a tap on a face the detector missed blurs it
/// too. The ink spreads from where the finger lands, the moment it lands,
/// and while that face is blurred a progress ring sits on the same spot.
/// {@endtemplate}
class const _TapToBlur({
  required final Widget image,
  required final bool busy,
  required final void Function(double x, double y) onTapped,
}) extends StatefulWidget {
  /// The mark's diameter on the tapped spot.
  static const double markSize = 40;

  @override
  State<_TapToBlur> createState() => _TapToBlurState();
}

class _TapToBlurState extends State<_TapToBlur> {
  /// Where the last tap landed, in the photo's own pixels on screen.
  Offset? _tapped;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appSpacing;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Where the ring sits: the tapped spot, or the middle when the
        // photo came back busy without a tap seen here.
        final mark =
            _tapped ??
            Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.image,
            if (widget.busy)
              Positioned(
                left: mark.dx - _TapToBlur.markSize / 2,
                top: mark.dy - _TapToBlur.markSize / 2,
                width: _TapToBlur.markSize,
                height: _TapToBlur.markSize,
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(spacing.xs),
                      child: const CircularProgressIndicator(
                        strokeWidth: BusyLabel.strokeWidth,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  excludeFromSemantics: true,
                  onTapUp: widget.busy
                      ? null
                      : (details) {
                          setState(() => _tapped = details.localPosition);
                          widget.onTapped(
                            details.localPosition.dx / constraints.maxWidth,
                            details.localPosition.dy / constraints.maxHeight,
                          );
                        },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
