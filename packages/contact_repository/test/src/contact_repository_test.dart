import 'package:contact_repository/contact_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_opener/link_opener.dart';
import 'package:mocktail/mocktail.dart';

class _MockLinkOpener extends Mock implements LinkOpener;

const _email = 'hola@example.com';

void main() {
  group(ContactRepository, () {
    late LinkOpener linkOpener;

    setUpAll(() => registerFallbackValue(Uri()));

    setUp(() {
      linkOpener = _MockLinkOpener();
      when(() => linkOpener.open(any())).thenAnswer((_) async => true);
    });

    ContactRepository build() =>
        ContactRepository(linkOpener: linkOpener, email: _email);

    Uri opened() =>
        verify(() => linkOpener.open(captureAny())).captured.single as Uri;

    test('knows the contact address', () {
      expect(build().email, equals(_email));
    });

    group('writeEmail', () {
      test('opens a mail to the address with the subject', () async {
        await build().writeEmail(subject: 'Ronda: algo que pasó');

        expect(
          opened().toString(),
          equals(
            'mailto:hola@example.com?subject=Ronda%3A%20algo%20que%20pas%C3%B3',
          ),
        );
      });

      test('adds the body when given', () async {
        await build().writeEmail(subject: 'Mis datos', body: 'Mi cuenta: a b');

        final uri = opened();
        expect(uri.path, equals(_email));
        expect(
          uri.query,
          equals('subject=Mis%20datos&body=Mi%20cuenta%3A%20a%20b'),
        );
      });

      test('throws a $ContactFailure when no mail app opens', () {
        when(() => linkOpener.open(any())).thenAnswer((_) async => false);

        expect(
          build().writeEmail(subject: 'x'),
          throwsA(isA<ContactFailure>()),
        );
      });

      test('throws a $ContactFailure when the platform fails', () {
        when(() => linkOpener.open(any())).thenThrow(Exception('no plugin'));

        expect(
          build().writeEmail(subject: 'x'),
          throwsA(isA<ContactFailure>()),
        );
      });
    });

    group('callHelpline', () {
      for (final (helpline, link) in [
        (Helpline.suicidePrevention, 'tel:08000767'),
        (Helpline.suicidePreventionMobile, 'tel:*0767'),
        (Helpline.emergencies, 'tel:911'),
      ]) {
        test('dials ${helpline.number} as $link', () async {
          await build().callHelpline(helpline);

          expect(opened().toString(), equals(link));
        });
      }

      test('throws a $ContactFailure when no dialer opens', () {
        when(() => linkOpener.open(any())).thenAnswer((_) async => false);

        expect(
          build().callHelpline(Helpline.emergencies),
          throwsA(isA<ContactFailure>()),
        );
      });
    });
  });
}
