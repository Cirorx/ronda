import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ronda/error_log/error_log.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(ErrorLogLink, () {
    testWidgets('opens the error log', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: ErrorLogLink()),
          ),
          GoRoute(
            path: ErrorLogPage.path,
            builder: (_, _) => const Text('errors'),
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

      await tester.tap(find.byTooltip('Errores de la app'));
      await tester.pumpAndSettle();

      expect(find.text('errors'), findsOneWidget);
    });
  });
}
