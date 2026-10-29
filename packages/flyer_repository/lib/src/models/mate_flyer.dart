import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// {@template mate_flyer}
/// A finished "Hay un mate de más" flyer: its image, ready to print, and
/// the landing its QR opens.
/// {@endtemplate}
final class const MateFlyer({
  /// The `flyers/{id}` document's id.
  required final String id,

  /// The flyer as a JPEG.
  required final Uint8List image,

  /// The address its QR code opens.
  required final String landingUrl,
}) extends Equatable {
  /// {@macro mate_flyer}
  this;

  @override
  List<Object?> get props => [id, image, landingUrl];
}
