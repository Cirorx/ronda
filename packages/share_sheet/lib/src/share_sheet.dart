import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// {@template share_sheet}
/// Opens the phone's share sheet with one file, so the person can print it,
/// send it or save it with whatever app they already use.
///
/// It holds no domain logic and logs nothing.
/// {@endtemplate}
class ShareSheet {
  /// {@macro share_sheet}
  new({SharePlus? sharePlus}) : _sharePlus = sharePlus ?? SharePlus.instance;

  final SharePlus _sharePlus;

  /// Shares [bytes] as a file called [fileName] of type [mimeType], with
  /// [title] on the sheet where the platform shows one. Returns whether
  /// the person picked somewhere to share it, as far as the platform tells.
  Future<bool> shareFile(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
    String? title,
  }) async {
    final result = await _sharePlus.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
        fileNameOverrides: [fileName],
        title: title,
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}
