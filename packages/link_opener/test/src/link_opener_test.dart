import 'package:flutter_test/flutter_test.dart';
import 'package:link_opener/link_opener.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  group(LinkOpener, () {
    test('uses url_launcher by default', () {
      expect(LinkOpener(), isA<LinkOpener>());
    });

    group('canOpen', () {
      test('asks the platform whether an app takes the link', () async {
        Uri? asked;
        final opener = LinkOpener(
          canLaunch: (url) async {
            asked = url;
            return true;
          },
        );

        expect(await opener.canOpen(Uri.parse('whatsapp://send')), isTrue);
        expect(asked, equals(Uri.parse('whatsapp://send')));
      });
    });

    group('open', () {
      final uri = Uri.parse('tel:911');

      test('hands the link to an app outside Ronda', () async {
        Uri? launched;
        LaunchMode? launchedMode;
        final opener = LinkOpener(
          launch: (url, {mode = LaunchMode.platformDefault}) async {
            launched = url;
            launchedMode = mode;
            return true;
          },
        );

        expect(await opener.open(uri), isTrue);
        expect(launched, equals(uri));
        expect(launchedMode, equals(LaunchMode.externalApplication));
      });

      test('says so when no app takes the link', () async {
        final opener = LinkOpener(
          launch: (_, {mode = LaunchMode.platformDefault}) async => false,
        );

        expect(await opener.open(uri), isFalse);
      });
    });
  });
}
