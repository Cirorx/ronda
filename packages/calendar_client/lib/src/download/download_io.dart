/// Downloading is a browser's way of saving a file; a phone has its calendar
/// app instead, so nothing calls this off the web.
Future<void> downloadTextFile({
  required String fileName,
  required String contents,
  required String mimeType,
}) => throw UnsupportedError('Only a browser downloads a file.');
