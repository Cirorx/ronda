import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/cuaderno/cuaderno.dart';

import '../../helpers/helpers.dart';

class _MockCuadernoCardCubit extends MockCubit<String?>
    implements CuadernoCardCubit;

void main() {
  group(CuadernoEntryCard, () {
    testWidgets("asks the day's hook and opens the cuaderno", (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              // The day the turn starts again at the sunset.
              body: CuadernoEntryCard(today: DateTime(2026, 10, 31)),
            ),
          ),
          GoRoute(
            path: CuadernoPage.path,
            builder: (_, _) => const Text('el cuaderno'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpApp(Router.withConfig(config: router));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '¿Viste un atardecer lindo en la rambla? Anotalo en el cuaderno.',
        ),
        findsOneWidget,
      );
      expect(find.text('¿Qué viste hoy?'), findsNothing);
      expect(
        find.text(
          'Una línea sobre tu barrio. La ves solo vos y queda en este '
          'teléfono.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('racha'), findsNothing);

      await tester.tap(find.text('Abrir el cuaderno'));
      await tester.pumpAndSettle();

      expect(find.text('el cuaderno'), findsOneWidget);
    });

    testWidgets('asks another hook on another weekday', (tester) async {
      await tester.pumpApp(
        // The day after.
        Scaffold(body: CuadernoEntryCard(today: DateTime(2026, 11))),
      );

      expect(
        find.text(
          '¿Querés acordarte de quién trajo los bizcochos? Para eso está el '
          'cuaderno.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('asks something different for 17 days, the new ones '
        'inviting something good', (tester) async {
      final hooks = <String>{};
      for (var day = 31; day < 31 + 17; day++) {
        await tester.pumpApp(
          Scaffold(body: CuadernoEntryCard(today: DateTime(2026, 10, day))),
        );
        final header = find.descendant(
          of: find.byType(Card),
          matching: find.byType(Text),
        );
        hooks.add(tester.widget<Text>(header.first).data!);
      }

      expect(hooks, hasLength(17));
      expect(
        hooks,
        contains('¿Algún vecino te dio una mano? Anotalo en el cuaderno.'),
      );
      expect(
        hooks,
        contains(
          '¿A quién le querés dar las gracias? Escribilo en el cuaderno.',
        ),
      );
    });

    testWidgets('in English', (tester) async {
      await tester.pumpApp(
        Scaffold(body: CuadernoEntryCard(today: DateTime(2026, 10, 31))),
        locale: const Locale('en'),
      );

      expect(
        find.text(
          'Saw a lovely sunset on the rambla? Write it in the notebook.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open the notebook'), findsOneWidget);
    });

    testWidgets('a new hook in English', (tester) async {
      await tester.pumpApp(
        // Seven days into the turn.
        Scaffold(body: CuadernoEntryCard(today: DateTime(2026, 11, 7))),
        locale: const Locale('en'),
      );

      expect(
        find.text('Did a neighbour give you a hand? Note it in the notebook.'),
        findsOneWidget,
      );
    });
  });

  group(BringReminder, () {
    late CuadernoCardCubit cubit;

    setUp(() => cubit = _MockCuadernoCardCubit());

    Future<void> pump(WidgetTester tester, {Locale? locale}) => tester.pumpApp(
      BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: BringReminder()),
      ),
      locale: locale ?? rioplatense,
    );

    testWidgets('shows the line the member chose to bring', (tester) async {
      when(() => cubit.state).thenReturn('El jacarandá floreció.');

      await pump(tester);

      expect(
        find.text('Llevás esta línea: «El jacarandá floreció.»'),
        findsOneWidget,
      );
    });

    testWidgets('in English', (tester) async {
      when(() => cubit.state).thenReturn('Rain.');

      await pump(tester, locale: const Locale('en'));

      expect(find.text("You're bringing this line: “Rain.”"), findsOneWidget);
    });

    testWidgets('shows nothing when none is chosen', (tester) async {
      when(() => cubit.state).thenReturn(null);

      await pump(tester);

      expect(find.byType(Text), findsNothing);
    });
  });
}
