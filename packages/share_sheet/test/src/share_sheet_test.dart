import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_sheet/share_sheet.dart';

class _MockSharePlus extends Mock implements SharePlus;

class _FakeShareParams extends Fake implements ShareParams;

void main() {
  group(ShareSheet, () {
    late SharePlus sharePlus;
    final bytes = Uint8List.fromList([1, 2, 3]);

    setUpAll(() => registerFallbackValue(_FakeShareParams()));

    setUp(() => sharePlus = _MockSharePlus());

    test('uses share_plus by default', () {
      expect(ShareSheet(), isA<ShareSheet>());
    });

    test('shares the bytes as one named file with a title', () async {
      when(() => sharePlus.share(any())).thenAnswer(
        (_) async => const ShareResult('whatsapp', ShareResultStatus.success),
      );

      final shared = await ShareSheet(sharePlus: sharePlus).shareFile(
        bytes,
        fileName: 'volante.jpg',
        mimeType: 'image/jpeg',
        title: 'Tu volante',
      );

      expect(shared, isTrue);
      final params =
          verify(() => sharePlus.share(captureAny())).captured.single
              as ShareParams;
      final file = params.files!.single;
      expect(await file.readAsBytes(), equals(bytes));
      expect(file.mimeType, equals('image/jpeg'));
      expect(params.fileNameOverrides, equals(['volante.jpg']));
      expect(params.title, equals('Tu volante'));
    });

    test('says so when the person closes the sheet', () async {
      when(() => sharePlus.share(any())).thenAnswer(
        (_) async => const ShareResult('', ShareResultStatus.dismissed),
      );

      expect(
        await ShareSheet(sharePlus: sharePlus)
            .shareFile(bytes, fileName: 'volante.jpg', mimeType: 'image/jpeg'),
        isFalse,
      );
    });
  });
}
