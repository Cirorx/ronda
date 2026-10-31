import 'package:material_ui/material_ui.dart';
import 'package:ronda_ui/src/extensions/build_context_extensions.dart';
import 'package:ronda_ui/src/widgets/busy_label.dart';

/// {@template tap_to_blur_photo}
/// A photo with its faces already blurred, where a tap on a face the
/// detector missed asks for it to be blurred too ([onTapped], with the spot
/// as a share of the width and the height). The ink spreads from where the
/// finger lands, the moment it lands, and while that face is blurred
/// ([busy]) a progress ring sits on the same spot.
///
/// Shared by every photo that leaves the phone: the "Un mate de más" flyer
/// and ¿Dónde queda?.
/// {@endtemplate}
class const TapToBlurPhoto({
  /// The photo.
  required final Widget image,

  /// Whether a tapped face is being blurred.
  required final bool busy,

  /// Called with the tapped spot, each a share (0 to 1) of the width and
  /// the height.
  required final void Function(double x, double y) onTapped,
  super.key,
}) extends StatefulWidget {
  /// {@macro tap_to_blur_photo}
  this;

  /// The mark's diameter on the tapped spot.
  static const double markSize = 40;

  @override
  State<TapToBlurPhoto> createState() => _TapToBlurPhotoState();
}

class _TapToBlurPhotoState extends State<TapToBlurPhoto> {
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
                left: mark.dx - TapToBlurPhoto.markSize / 2,
                top: mark.dy - TapToBlurPhoto.markSize / 2,
                width: TapToBlurPhoto.markSize,
                height: TapToBlurPhoto.markSize,
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
