part of 'face_blur.dart';

/// How much a detected box grows on each side: ML Kit's box stops at the
/// brow and the chin, and hair and ears identify people too.
const _facePadding = 0.25;

/// A tapped face's side, as a share of the photo's short side.
const _tappedFaceSide = 0.2;

/// How many cells a pixelated face is across, at most. Few enough that
/// nobody is recognisable.
const _cellsAcross = 8;

/// The smallest cell, in pixels.
const _minCellSize = 8;

/// The JPEG quality of a blurred photo.
const _jpegQuality = 85;

/// Decodes [jpeg], scales it down to [FaceBlur.longSide], pixelates each of
/// [faces] (in [jpeg]'s pixels, padded by [_facePadding]) and encodes it
/// again without EXIF. Runs in an isolate: it touches every pixel.
///
/// Throws a [FaceBlurException] when [jpeg] isn't an image.
BlurredPhoto _blurFaces(Uint8List jpeg, List<FaceBox> faces) {
  final source = _decode(jpeg);
  final longest = math.max(source.width, source.height);
  final scale = longest > FaceBlur.longSide ? FaceBlur.longSide / longest : 1.0;
  final image = scale < 1
      ? img.copyResize(
          source,
          width: (source.width * scale).round(),
          height: (source.height * scale).round(),
          interpolation: img.Interpolation.average,
        )
      : source;
  for (final face in faces) {
    final padX = face.width * _facePadding;
    final padY = face.height * _facePadding;
    _pixelate(
      image,
      FaceBox(
        (face.left - padX) * scale,
        (face.top - padY) * scale,
        (face.right + padX) * scale,
        (face.bottom + padY) * scale,
      ),
    );
  }
  return _encode(image, blurredFaces: faces.length);
}

/// [photo] with one more face pixelated: a square of [_tappedFaceSide]
/// centred on ([x], [y]), each a share of the width and the height.
BlurredPhoto _blurTappedFace(BlurredPhoto photo, double x, double y) {
  final image = _decode(photo.jpeg);
  final half = math.min(image.width, image.height) * _tappedFaceSide / 2;
  final cx = x.clamp(0, 1) * image.width;
  final cy = y.clamp(0, 1) * image.height;
  _pixelate(image, FaceBox(cx - half, cy - half, cx + half, cy + half));
  return _encode(image, blurredFaces: photo.blurredFaces + 1);
}

/// Replaces [box] in [image] (clamped to it) with cells of one colour each,
/// the average of the pixels under it: about [_cellsAcross] cells across
/// the box's long side, never smaller than [_minCellSize].
void _pixelate(img.Image image, FaceBox box) {
  final left = box.left.floor().clamp(0, image.width);
  final top = box.top.floor().clamp(0, image.height);
  final right = box.right.ceil().clamp(0, image.width);
  final bottom = box.bottom.ceil().clamp(0, image.height);
  final longest = math.max(right - left, bottom - top);
  final cell = math.max(_minCellSize, (longest / _cellsAcross).ceil());
  for (var y = top; y < bottom; y += cell) {
    for (var x = left; x < right; x += cell) {
      final endX = math.min(x + cell, right);
      final endY = math.min(y + cell, bottom);
      var r = 0.0;
      var g = 0.0;
      var b = 0.0;
      for (var py = y; py < endY; py++) {
        for (var px = x; px < endX; px++) {
          final pixel = image.getPixel(px, py);
          r += pixel.r;
          g += pixel.g;
          b += pixel.b;
        }
      }
      final count = (endX - x) * (endY - y);
      final colour = img.ColorRgb8(
        (r / count).round(),
        (g / count).round(),
        (b / count).round(),
      );
      img.fillRect(
        image,
        x1: x,
        y1: y,
        x2: endX - 1,
        y2: endY - 1,
        color: colour,
      );
    }
  }
}

img.Image _decode(Uint8List jpeg) {
  final img.Image? image;
  try {
    image = img.decodeJpg(jpeg);
  } on img.ImageException {
    throw const FaceBlurException('not a JPEG');
  }
  if (image == null) throw const FaceBlurException('not a JPEG');
  return image;
}

BlurredPhoto _encode(img.Image image, {required int blurredFaces}) {
  // Without this `image` writes the decoded EXIF back, location included.
  image.exif = img.ExifData();
  return BlurredPhoto._(
    jpeg: img.encodeJpg(image, quality: _jpegQuality),
    width: image.width,
    height: image.height,
    blurredFaces: blurredFaces,
  );
}
