import 'package:equatable/equatable.dart';

/// {@template mate_flyer_result}
/// What the `make_mate_flyer` callable answers: the new `flyers/{id}`
/// document's id, where its image is in Storage and the address its QR
/// opens.
/// {@endtemplate}
final class const MateFlyerResult({
  /// The `flyers/{id}` document's id.
  required final String flyerId,

  /// The flyer image's Storage path, `flyers/{uid}/{flyerId}.jpg`.
  required final String imagePath,

  /// The landing the QR opens, `…/f/{flyerId}`.
  required final String landingUrl,
}) extends Equatable {
  /// {@macro mate_flyer_result}
  this;

  /// Reads the callable's answer; throws a [FormatException] for any other
  /// shape.
  factory fromJson(Object? json) => switch (json) {
    {
      'flyerId': final String flyerId,
      'imagePath': final String imagePath,
      'landingUrl': final String landingUrl,
    } =>
      MateFlyerResult(
        flyerId: flyerId,
        imagePath: imagePath,
        landingUrl: landingUrl,
      ),
    _ => throw const FormatException('make_mate_flyer returned no flyer'),
  };

  @override
  List<Object?> get props => [flyerId, imagePath, landingUrl];
}
