import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/attendance/attendance.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

class _MockAttendanceCubit extends MockCubit<AttendanceState>
    implements AttendanceCubit;

void main() {
  group(AttendancePage, () {
    testWidgets('follows the roll of its ronda and week', (tester) async {
      final repository = _MockRondaRepository();
      when(() => repository.watchRoll('ronda-1', '2026-W45'))
          .thenAnswer((_) => Stream.value(AttendanceFixtures.roll()));

      await tester.pumpApp(
        RepositoryProvider<RondaRepository>.value(
          value: repository,
          child: const AttendancePage(rondaId: 'ronda-1', week: '2026-W45'),
        ),
      );
      await tester.pump();

      expect(find.text('¿Quién vino hoy?'), findsOneWidget);
      expect(find.text('Anotaste a 1 de 3.'), findsOneWidget);
    });

    test('builds its locations', () {
      expect(
        AttendancePage.location('r 1', '2026-W45'),
        '/asistencia/r%201/2026-W45',
      );
      expect(
        AttendancePage.location('r1', '2026-W45', admin: true),
        '/admin/asistencia/r1/2026-W45',
      );
    });
  });

  group(AttendanceView, () {
    late AttendanceCubit cubit;

    setUp(() {
      cubit = _MockAttendanceCubit();
      when(() => cubit.marked(any(), came: any(named: 'came')))
          .thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester,
      AttendanceState state, {
      double textScale = 1,
    }) async {
      when(() => cubit.state).thenReturn(state);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpApp(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: BlocProvider.value(
            value: cubit,
            child: const AttendanceView(),
          ),
        ),
      );
      tester.view.physicalSize = const Size(360, 2400);
      await tester.pump();
    }

    AttendanceState ready({
      Map<String, bool> pending = const {},
      HostsFailureReason? tapFailure,
    }) => AttendanceState(
      status: AttendanceStatus.ready,
      roll: AttendanceFixtures.roll(),
      pending: pending,
      tapFailure: tapFailure,
    );

    testWidgets('lists each person with Vino and No vino, and who sees it', (
      tester,
    ) async {
      await pump(tester, ready(pending: const {'demo-103': false}));

      expect(
        find.text('Jueves 16:00 · mate en la rambla · frente al quiosco'),
        findsOneWidget,
      );
      expect(find.text('Nadie más ve esta lista.'), findsOneWidget);
      expect(find.text('Anotaste a 2 de 3.'), findsOneWidget);
      for (final name in ['Ana', 'Jorge', 'Mirta']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Vino'), findsNWidgets(3));
      expect(find.text('No vino'), findsNWidgets(3));
      expect(
        find.ancestor(
          of: find.text('Vino').at(1),
          matching: find.byType(FilledButton),
        ),
        findsOneWidget,
      );
      String? label(String name) => tester
          .widget<Semantics>(
            find
                .ancestor(of: find.text(name), matching: find.byType(Semantics))
                .first,
          )
          .properties
          .label;
      expect(label('Ana'), 'Ana: No vino');
      expect(label('Jorge'), 'Jorge: Vino');
      expect(label('Mirta'), 'Mirta: sin anotar');
    });

    testWidgets('a tap marks the person through the cubit', (tester) async {
      await pump(tester, ready());

      await tester.tap(find.text('Vino').first);
      await tester.tap(find.text('No vino').last);

      verify(() => cubit.marked('demo-103', came: true)).called(1);
      verify(() => cubit.marked('demo-101', came: false)).called(1);
    });

    testWidgets('stacks the buttons at large text', (tester) async {
      await pump(tester, ready(), textScale: 2);

      expect(find.text('Vino'), findsNWidgets(3));
      expect(
        find.ancestor(
          of: find.text('Vino').first,
          matching: find.byType(Expanded),
        ),
        findsNothing,
      );
    });

    testWidgets('says why a tap did not save', (tester) async {
      await pump(tester, ready(tapFailure: HostsFailureReason.passed));
      expect(
        find.text(
          'Esa reunión fue hace más de una semana: ya no se puede cambiar.',
        ),
        findsOneWidget,
      );

      await pump(tester, ready(tapFailure: HostsFailureReason.other));
      expect(find.text('No se guardó. Probá de nuevo.'), findsOneWidget);
    });

    testWidgets('waits, then says there is no list, or retries', (
      tester,
    ) async {
      await pump(tester, const AttendanceState());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await pump(tester, const AttendanceState(status: AttendanceStatus.none));
      expect(
        find.text('Todavía no hay lista para esa reunión.'),
        findsOneWidget,
      );

      await pump(
        tester,
        const AttendanceState(status: AttendanceStatus.forbidden),
      );
      expect(
        find.text('Todavía no hay lista para esa reunión.'),
        findsOneWidget,
      );

      await pump(
        tester,
        const AttendanceState(status: AttendanceStatus.failure),
      );
      expect(
        find.text('No pudimos leer la lista. Probá de nuevo.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Probar de nuevo'));
      verify(cubit.subscribe).called(1);
    });
  });
}
