import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ronda/agent_trace/agent_trace.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AgentTraceLink, () {
    testWidgets('opens the trace', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: AgentTraceLink()),
          ),
          GoRoute(
            path: AgentTracePage.path,
            builder: (_, _) => const Text('trace'),
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

      await tester.tap(find.byTooltip('Lo que mandó el programa'));
      await tester.pumpAndSettle();

      expect(find.text('trace'), findsOneWidget);
    });
  });
}
