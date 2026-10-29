import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/mate_flyer/mate_flyer.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(MateFlyerEntry, () {
    testWidgets('says what the flyer is for and opens the one of its ronda', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(body: MateFlyerEntry(rondaId: 'ronda-1')),
          ),
          GoRoute(
            path: MateFlyerPage.path,
            builder: (_, state) =>
                Text('flyer ${state.pathParameters['rondaId']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          locale: rioplatense,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );

      expect(find.text('Un mate de más'), findsOneWidget);
      expect(
        find.text(
          'Tu ronda guarda un lugar para alguien nuevo. Hacé un volante con '
          'una foto de las cosas del grupo para colgar en el barrio.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Hacer el volante'));
      await tester.pumpAndSettle();

      expect(find.text('flyer ronda-1'), findsOneWidget);
    });
  });
}
