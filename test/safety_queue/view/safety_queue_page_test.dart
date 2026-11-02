import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/safety_queue/safety_queue.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:safety_repository/safety_repository.dart';

import '../../helpers/helpers.dart';
import '../helpers.dart';

class _MockSafetyRepository extends Mock implements SafetyRepository;

class _MockSafetyQueueCubit extends MockCubit<SafetyQueueState>
    implements SafetyQueueCubit;

void main() {
  group(SafetyQueuePage, () {
    testWidgets('follows the queue in $SafetyQueueView', (tester) async {
      final repository = _MockSafetyRepository();
      when(repository.watchQueue)
          .thenAnswer((_) => Stream.value(SafetyFixtures.queue));
      when(() => repository.markRead(any())).thenAnswer((_) async {});

      await tester.pumpApp(
        RepositoryProvider<SafetyRepository>.value(
          value: repository,
          child: const SafetyQueuePage(),
        ),
        size: const Size(360, 2400),
      );
      await tester.pump();

      expect(find.byType(ReportCard), findsNWidgets(3));
      verify(() => repository.markRead('rep1')).called(1);
    });
  });

  group(SafetyQueueView, () {
    late SafetyQueueCubit cubit;

    setUp(() {
      cubit = _MockSafetyQueueCubit();
      for (final call in <Future<void> Function(String)>[
        cubit.archive,
        cubit.reopen,
        cubit.separate,
        cubit.remove,
        cubit.joinAgain,
        cubit.letBackIn,
      ]) {
        when(() => call(any())).thenAnswer((_) async {});
      }
    });

    Future<void> pump(
      WidgetTester tester,
      SafetyQueueState state, {
      Locale locale = rioplatense,
    }) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(value: cubit, child: const SafetyQueueView()),
        locale: locale,
        size: const Size(360, 2400),
      );
    }

    SafetyQueueState ready({
      SafetyQueue? queue,
      SafetyQueueTab tab = SafetyQueueTab.open,
      Set<String> fresh = const {},
      String? busy,
      bool actionFailed = false,
    }) => SafetyQueueState(
      status: SafetyQueueStatus.ready,
      queue: queue ?? SafetyFixtures.queue,
      tab: tab,
      fresh: fresh,
      busy: busy,
      actionFailed: actionFailed,
    );

    String tap(String action, String id) =>
        '${ReportCard.identifier}.$action.$id';

    group('renders', () {
      testWidgets('a ring while it reads', (tester) async {
        await pump(tester, const SafetyQueueState());

        expect(find.text('Buscando los reportes…'), findsOneWidget);
      });

      testWidgets('a refusal', (tester) async {
        await pump(
          tester,
          const SafetyQueueState(status: SafetyQueueStatus.forbidden),
        );

        expect(find.byType(ReportCard), findsNothing);
      });

      testWidgets('a failed read, with Probar de nuevo', (tester) async {
        await pump(
          tester,
          const SafetyQueueState(status: SafetyQueueStatus.failure),
        );

        expect(
          find.text('No pudimos leer los reportes. Probá de nuevo.'),
          findsOneWidget,
        );
        await tester.tap(find.byType(OutlinedButton));
        verify(cubit.subscribe).called(1);
      });

      testWidgets('the open reports, two reporters about Beto on top', (
        tester,
      ) async {
        await pump(tester, ready(fresh: {'rep1'}));

        expect(find.text('Abiertos (3)'), findsOneWidget);
        final headers = tester
            .widgetList<Text>(find.textContaining('contó sobre'))
            .map((text) => text.data)
            .toList();
        expect(
          headers,
          equals([
            'Ana contó sobre Beto',
            'Cora contó sobre Beto',
            'Dani contó sobre alguien de afuera',
          ]),
        );
        expect(find.text('2 personas contaron sobre Beto'), findsNWidgets(2));
        expect(find.text('Nuevo'), findsOneWidget);
        expect(find.text('Me molestó'), findsNWidgets(3));
        expect(find.text('Me insistió'), findsNWidgets(3));
        expect(find.textContaining('mate en la rambla'), findsNWidgets(3));
        expect(
          find.bySemanticsIdentifier(tap('separate', 'rep3')),
          findsNothing,
        );
        expect(find.bySemanticsIdentifier(tap('remove', 'rep3')), findsNothing);
      });

      testWidgets('in English', (tester) async {
        await pump(tester, ready(), locale: const Locale('en'));

        expect(find.text('Ana told us about Beto'), findsOneWidget);
        expect(
          find.text('Dani told us about someone from outside'),
          findsOneWidget,
        );
      });

      testWidgets('a withdrawn report, marked, and what was added', (
        tester,
      ) async {
        await pump(
          tester,
          ready(
            queue: SafetyQueue(
              reports: [
                SafetyFixtures.report(
                  withdrawn: true,
                  additions: [
                    ReportAddition(text: 'Y el jueves', at: SafetyFixtures.at),
                  ],
                ),
              ],
            ),
          ),
        );

        expect(find.text('Retirado'), findsOneWidget);
        expect(find.textContaining('Agregó el'), findsOneWidget);
        expect(find.text('Y el jueves'), findsOneWidget);
      });

      testWidgets('the archived ones', (tester) async {
        await pump(tester, ready(tab: SafetyQueueTab.archived));

        expect(find.text('Eva contó sobre Fede'), findsOneWidget);
        expect(find.bySemanticsIdentifier(tap('reopen', 'rep4')), findsOne);
      });

      testWidgets('when there are none', (tester) async {
        await pump(tester, ready(queue: const SafetyQueue()));
        expect(find.text('No hay reportes abiertos.'), findsOneWidget);
      });

      testWidgets('when none are archived', (tester) async {
        await pump(
          tester,
          ready(queue: const SafetyQueue(), tab: SafetyQueueTab.archived),
        );
        expect(find.text('No hay reportes archivados.'), findsOneWidget);
      });

      testWidgets('a failed action', (tester) async {
        await pump(tester, ready(actionFailed: true));

        expect(find.text('No se pudo. Probá de nuevo.'), findsOneWidget);
      });

      testWidgets('a separated pair, still together, and who is out', (
        tester,
      ) async {
        await pump(
          tester,
          ready(
            queue: SafetyQueue(
              reports: [SafetyFixtures.beto, SafetyFixtures.archived],
              separated: const [
                SeparatedPair(
                  id: 'ana_beto',
                  uidA: 'ana',
                  uidB: 'beto',
                  nameA: 'Ana',
                  nameB: 'Beto',
                  togetherLine: 'Sábado a la tarde',
                ),
                SeparatedPair(id: 'x_y', uidA: 'x', uidB: 'y'),
              ],
              removed: [
                RemovedPerson(
                  uid: 'beto',
                  firstName: 'Beto',
                  at: SafetyFixtures.at,
                  notice: RemovalNotice.pending,
                ),
              ],
            ),
          ),
        );

        expect(
          find.text(
            'Siguen juntos en Sábado a la tarde; esto vale desde la próxima '
            'vez.',
          ),
          findsOneWidget,
        );
        expect(find.text('Fuera de Ronda.'), findsOneWidget);
        expect(
          find.bySemanticsIdentifier(tap('separate', 'rep1')),
          findsNothing,
        );
        expect(find.bySemanticsIdentifier(tap('remove', 'rep1')), findsNothing);
        expect(find.text('Ana y Beto'), findsOneWidget);
        expect(find.text('alguien y alguien'), findsOneWidget);
        expect(find.textContaining('Beto, desde el'), findsOneWidget);
        expect(find.text('El aviso le sale a las 9.'), findsOneWidget);
      });

      testWidgets('separated with nobody together says just that', (
        tester,
      ) async {
        await pump(
          tester,
          ready(
            queue: SafetyQueue(
              reports: [SafetyFixtures.beto],
              separated: const [
                SeparatedPair(id: 'ana_beto', uidA: 'beto', uidB: 'ana'),
              ],
            ),
          ),
        );

        expect(
          find.text('Separados: no los ponemos juntos de nuevo.'),
          findsOneWidget,
        );
      });

      testWidgets('buttons wait while something is on its way', (tester) async {
        await pump(tester, ready(busy: 'rep1'));

        final buttons = tester.widgetList<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        expect(buttons.every((b) => b.onPressed == null), isTrue);
      });
    });

    group('acts', () {
      testWidgets('changes tabs', (tester) async {
        await pump(tester, ready());

        await tester.tap(find.text('Archivados'));

        verify(() => cubit.tabChanged(SafetyQueueTab.archived)).called(1);
      });

      testWidgets('separates, archives and reopens', (tester) async {
        await pump(tester, ready());
        await tester.tap(find.bySemanticsIdentifier(tap('separate', 'rep1')));
        await tester.tap(find.bySemanticsIdentifier(tap('archive', 'rep1')));
        verify(() => cubit.separate('rep1')).called(1);
        verify(() => cubit.archive('rep1')).called(1);
      });

      testWidgets('reopens an archived one', (tester) async {
        await pump(tester, ready(tab: SafetyQueueTab.archived));
        await tester.tap(find.bySemanticsIdentifier(tap('reopen', 'rep4')));
        verify(() => cubit.reopen('rep4')).called(1);
      });

      testWidgets('Sacar de Ronda asks first; Mejor no keeps them', (
        tester,
      ) async {
        await pump(tester, ready());
        final remove = find.bySemanticsIdentifier(tap('remove', 'rep1'));

        await tester.tap(remove);
        await tester.pumpAndSettle();
        expect(find.text('¿Sacás a Beto de Ronda?'), findsOneWidget);
        expect(find.textContaining('Ya no estás en esta ronda.'), findsOne);
        await tester.tap(
          find.bySemanticsIdentifier(
            '${ReportCard.removeSheetIdentifier}.secondary',
          ),
        );
        await tester.pumpAndSettle();
        verifyNever(() => cubit.remove(any()));

        await tester.tap(remove);
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsIdentifier(
            '${ReportCard.removeSheetIdentifier}.primary',
          ),
        );
        await tester.pumpAndSettle();
        verify(() => cubit.remove('rep1')).called(1);
      });

      testWidgets('joins a pair again and lets someone back in', (
        tester,
      ) async {
        await pump(
          tester,
          ready(
            queue: SafetyQueue(
              separated: const [
                SeparatedPair(id: 'ana_beto', uidA: 'ana', uidB: 'beto'),
              ],
              removed: [
                RemovedPerson(
                  uid: 'beto',
                  firstName: 'Beto',
                  at: SafetyFixtures.at,
                ),
              ],
            ),
          ),
        );

        await tester.tap(
          find.bySemanticsIdentifier(
            '${SafetyQueueView.joinAgainIdentifier}.ana_beto',
          ),
        );
        await tester.tap(
          find.bySemanticsIdentifier(
            '${SafetyQueueView.letBackInIdentifier}.beto',
          ),
        );

        verify(() => cubit.joinAgain('ana_beto')).called(1);
        verify(() => cubit.letBackIn('beto')).called(1);
      });
    });
  });

  group(SafetyQueueLink, () {
    Future<void> pump(WidgetTester tester, int unread) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: SafetyQueueLink()),
          ),
          GoRoute(
            path: SafetyQueuePage.path,
            builder: (_, _) => const Text('la cola'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider.value(
          value: unreadReports(unread),
          child: MaterialApp.router(
            theme: AppTheme.light,
            locale: rioplatense,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
    }

    testWidgets('opens the queue', (tester) async {
      await pump(tester, 0);

      await tester.tap(find.bySemanticsIdentifier(SafetyQueueLink.identifier));
      await tester.pumpAndSettle();

      expect(find.text('la cola'), findsOneWidget);
    });

    testWidgets('carries the unread count, said in words', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, 3);

      expect(find.text('3'), findsOneWidget);
      expect(
        tester.getSemantics(
          find.bySemanticsIdentifier(SafetyQueueLink.identifier),
        ),
        isSemantics(value: '3 reportes sin leer'),
      );
      semantics.dispose();
    });
  });
}
