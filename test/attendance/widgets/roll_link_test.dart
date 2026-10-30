import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/attendance/attendance.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group(RollLink, () {
    late RondaRepository repository;

    setUp(() => repository = _MockRondaRepository());

    Future<void> pump(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: RollLink(rondaId: 'ronda-1', week: '2026-W45'),
            ),
          ),
          GoRoute(
            path: AttendancePage.path,
            builder: (_, state) => Text(
              'roll ${state.pathParameters['rondaId']} '
              '${state.pathParameters['week']}',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        RepositoryProvider.value(
          value: repository,
          child: MaterialApp.router(
            theme: AppTheme.light,
            locale: rioplatense,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('opens the roll once it exists', (tester) async {
      when(() => repository.watchRoll('ronda-1', '2026-W45'))
          .thenAnswer((_) => Stream.value(AttendanceFixtures.roll()));
      await pump(tester);

      expect(find.text('Anotaste a 1 de 3.'), findsOneWidget);
      await tester.tap(find.text('¿Quién vino hoy?'));
      await tester.pumpAndSettle();

      expect(find.text('roll ronda-1 2026-W45'), findsOneWidget);
    });

    testWidgets('shows nothing before the roll exists', (tester) async {
      when(() => repository.watchRoll('ronda-1', '2026-W45'))
          .thenAnswer((_) => Stream.value(null));
      await pump(tester);

      expect(find.text('¿Quién vino hoy?'), findsNothing);
    });
  });
}
