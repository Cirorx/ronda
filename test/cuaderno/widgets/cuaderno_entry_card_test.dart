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
    testWidgets('asks "¿Qué viste hoy?" and opens the cuaderno', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: CuadernoEntryCard()),
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

      expect(find.text('¿Qué viste hoy?'), findsOneWidget);
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

    testWidgets('in English', (tester) async {
      await tester.pumpApp(
        const Scaffold(body: CuadernoEntryCard()),
        locale: const Locale('en'),
      );

      expect(find.text('Open the notebook'), findsOneWidget);
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
