import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockSeguimosCountsCubit extends MockCubit<SeguimosCountsState>
    implements SeguimosCountsCubit;

void main() {
  group(SeguimosCountsSection, () {
    late SeguimosCountsCubit cubit;

    setUp(() => cubit = _MockSeguimosCountsCubit());

    Future<void> pump(
      WidgetTester tester,
      SeguimosCountsState state, {
      Locale locale = rioplatense,
    }) async {
      whenListen(
        cubit,
        const Stream<SeguimosCountsState>.empty(),
        initialState: state,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const SingleChildScrollView(child: SeguimosCountsSection()),
        ),
        locale: locale,
      );
    }

    const ready = SeguimosCountsState(status: SeguimosCountsStatus.ready);

    testWidgets('shows nothing until the counts are read, or when refused', (
      tester,
    ) async {
      await pump(tester, const SeguimosCountsState());
      expect(find.text('¿Seguimos?'), findsNothing);

      await pump(
        tester,
        const SeguimosCountsState(status: SeguimosCountsStatus.failure),
      );
      expect(find.text('¿Seguimos?'), findsNothing);
    });

    testWidgets('says when no ronda has been asked yet', (tester) async {
      await pump(tester, ready);

      expect(find.text('¿Seguimos?'), findsOneWidget);
      expect(
        find.text('Todavía no se preguntó en ninguna ronda.'),
        findsOneWidget,
      );
    });

    testWidgets('shows each ronda by its counts and where it stands', (
      tester,
    ) async {
      await pump(
        tester,
        SeguimosCountsState(
          status: SeguimosCountsStatus.ready,
          rondas: [
            const SeguimosCounts(
              rondaId: 'r1',
              line: 'Sábado a la tarde · mate en la rambla',
              status: SeguimosStatus.open,
              yes: 2,
              no: 1,
              unanswered: 3,
            ),
            SeguimosCounts(
              rondaId: 'r2',
              line: 'Martes a la tarde · mate en la rambla',
              status: SeguimosStatus.season,
              yes: 4,
              no: 1,
              unanswered: 1,
              seasonEnd: DateTime(2026, 11, 24),
            ),
            const SeguimosCounts(
              rondaId: 'r3',
              line: 'Jueves a la tarde · truco',
              status: SeguimosStatus.didntFill,
              yes: 2,
              no: 0,
              unanswered: 3,
              join: 1,
              wait: 2,
            ),
            const SeguimosCounts(
              rondaId: 'r4',
              line: 'Domingo a la mañana · caminata',
              status: SeguimosStatus.season,
              yes: 4,
              no: 0,
              unanswered: 0,
            ),
          ],
        ),
      );

      expect(
        find.text('Sábado a la tarde · mate en la rambla'),
        findsOneWidget,
      );
      expect(find.text('Sí 2 · No 1 · Sin contestar 3'), findsOneWidget);
      expect(
        find.text('Abierta: se cierra con el próximo ¿Venís?.'),
        findsOneWidget,
      );
      expect(find.text('Siguen, hasta el 24/11.'), findsOneWidget);
      expect(
        find.text('No llegó. Quieren otro grupo: 1. Esperan: 2.'),
        findsOneWidget,
      );
      expect(find.text('Siguen, hasta el .'), findsOneWidget);
    });

    testWidgets('reads in English', (tester) async {
      await pump(tester, ready, locale: const Locale('en'));

      expect(find.text('No ronda has been asked yet.'), findsOneWidget);
    });
  });
}
