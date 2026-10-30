import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ronda/acta/acta.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(ActaLink, () {
    testWidgets("opens its ronda's acta", (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(body: ActaLink(rondaId: 'ronda-1')),
          ),
          GoRoute(
            path: ActaPage.path,
            builder: (_, state) =>
                Text('acta ${state.pathParameters['rondaId']}'),
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

      await tester.tap(find.text('Lo que hizo el programa esta semana'));
      await tester.pumpAndSettle();

      expect(find.text('acta ronda-1'), findsOneWidget);
    });
  });
}
