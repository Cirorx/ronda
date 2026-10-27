import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(TermsNote, () {
    late int linkTaps;

    setUp(() => linkTaps = 0);

    Widget buildSubject({String trailing = '.'}) {
      return TermsNote(
        identifier: 'bienvenida.condiciones',
        lead: 'Al seguir, aceptás las',
        linkLabel: 'condiciones de Ronda',
        trailing: trailing,
        onLinkTap: () => linkTaps++,
      );
    }

    group('renders', () {
      testWidgets('the lead, the link and the trailing text', (tester) async {
        await tester.pumpApp(buildSubject());

        expect(find.text('Al seguir, aceptás las'), findsOneWidget);
        expect(find.text('condiciones de Ronda'), findsOneWidget);
        expect(find.text('.'), findsOneWidget);
      });

      testWidgets('no trailing text when it is empty', (tester) async {
        await tester.pumpApp(buildSubject(trailing: ''));

        expect(find.text('.'), findsNothing);
      });

      testWidgets('the link as a link with its identifier', (tester) async {
        await tester.pumpApp(buildSubject());

        expect(
          tester.getSemantics(
            find.bySemanticsIdentifier('bienvenida.condiciones'),
          ),
          isSemantics(
            label: 'condiciones de Ronda',
            isLink: true,
            hasTapAction: true,
          ),
        );
      });

      testWidgets('the link with a 48 dp tap target', (tester) async {
        await tester.pumpApp(buildSubject());

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });

      for (final MapEntry(key: name, value: theme) in themes.entries) {
        for (final scale in textScales) {
          testWidgets('without overflow in $name at ${scale}x text', (
            tester,
          ) async {
            await tester.pumpApp(
              Center(child: buildSubject()),
              theme: theme(),
              textScale: scale,
            );

            expect(tester.takeException(), isNull);
          });
        }
      }
    });

    group('calls onLinkTap', () {
      testWidgets('when the link is tapped', (tester) async {
        await tester.pumpApp(buildSubject());

        await tester.tap(find.bySemanticsIdentifier('bienvenida.condiciones'));

        expect(linkTaps, 1);
      });

      testWidgets('never when the lead is tapped', (tester) async {
        await tester.pumpApp(buildSubject());

        await tester.tap(find.text('Al seguir, aceptás las'));

        expect(linkTaps, 0);
      });
    });
  });
}
