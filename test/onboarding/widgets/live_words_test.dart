import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/onboarding/onboarding.dart';

import '../../helpers/helpers.dart';

void main() {
  group(LiveWords, () {
    testWidgets('shows the caption and the words heard', (tester) async {
      await tester.pumpApp(const LiveWords(words: 'Hola, soy Marta'));

      expect(find.text('Lo que vamos escuchando'), findsOneWidget);
      expect(find.text('Hola, soy Marta'), findsOneWidget);
    });

    testWidgets('says the caption in English', (tester) async {
      await tester.pumpApp(
        const LiveWords(words: 'Hello'),
        locale: const Locale('en'),
      );

      expect(find.text('What we hear so far'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('follows the words as they are revised', (tester) async {
      await tester.pumpApp(const LiveWords(words: 'Hola'));
      await tester.pumpApp(const LiveWords(words: 'Hola, soy Marta'));

      expect(find.text('Hola'), findsNothing);
      expect(find.text('Hola, soy Marta'), findsOneWidget);
    });
  });
}
