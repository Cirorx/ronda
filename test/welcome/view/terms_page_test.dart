import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/welcome/welcome.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(TermsPage, () {
    test('sits under the welcome screen', () {
      expect(
        TermsPage.path,
        equals('${WelcomePage.path}/${TermsPage.segment}'),
      );
    });

    testWidgets('renders the seven points and where things happen', (
      tester,
    ) async {
      await tester.pumpApp(const TermsPage());

      expect(find.text('Las condiciones, en corto'), findsOneWidget);
      for (final point in [
        'Ronda es gratis. Nunca te va a pedir plata.',
        'Las rondas son en lugares públicos y solo para mayores de 18.',
        'Guardamos lo justo: tu nombre, tu edad más o menos',
        'Si mandás un audio, un programa lo pasa a texto',
        'Tus datos los ves y los borrás cuando quieras, desde Ajustes.',
        'Si alguien te incomoda, reportalo. Lo lee una persona.',
        'Si algo falla, la app manda un aviso anónimo, sin tus datos',
      ]) {
        await tester.scrollUntilVisible(find.textContaining(point), 100);
        expect(find.textContaining(point), findsOneWidget);
      }
      final where = find.text(
        'Dónde pasa cada cosa: tus datos se guardan en Brasil; el audio lo '
        'procesa Meta y el inicio de sesión Google, en EE. UU.',
      );
      await tester.scrollUntilVisible(where, 100);
      expect(where, findsOneWidget);
      await tester.scrollUntilVisible(find.text('Entendido'), 100);
      expect(find.text('Entendido'), findsOneWidget);
    });

    testWidgets('names itself "Condiciones" in the top bar', (tester) async {
      await tester.pumpApp(const TermsPage());

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Condiciones'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sets the points apart with space, not rules', (tester) async {
      await tester.pumpApp(const TermsPage());

      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('renders in English', (tester) async {
      await tester.pumpApp(const TermsPage(), locale: const Locale('en'));

      expect(find.text('The terms, in short'), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
    });
  });
}
