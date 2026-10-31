import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// {@template postcard}
/// The week's postcard: a drawing of objects and places from the week's
/// lines, never people. It lives only in memory; the phone's share sheet is
/// how it is kept.
/// {@endtemplate}
final class const Postcard(
  /// The postcard as a JPEG.
  final Uint8List image,
) extends Equatable {
  /// {@macro postcard}
  this;

  @override
  List<Object?> get props => [image];
}
