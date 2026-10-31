import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Saves [contents] as a file called [fileName] through the browser's
/// download: a link to an object URL, clicked once, then forgotten.
Future<void> downloadTextFile({
  required String fileName,
  required String contents,
  required String mimeType,
}) async {
  final blob = web.Blob(
    [contents.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..click();
  web.URL.revokeObjectURL(url);
}
