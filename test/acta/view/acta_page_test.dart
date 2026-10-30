import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:ronda/acta/acta.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockOrganiserRepository extends Mock implements OrganiserRepository;

class _MockActaCubit extends MockCubit<ActaState> implements ActaCubit;

final _acta = Acta(
  week: '2026-W45',
  lines: [
    ActaLine(
      id: 'a',
      at: DateTime(2026, 11, 4, 18),
      summary: 'Miró el pronóstico del jueves 5/11 a las 16:00: lluvia 80%.',
      byHost: false,
    ),
    ActaLine(
      id: 'b',
      at: DateTime(2026, 11, 4, 19, 30),
      summary: 'Mirta eligió: al Salón Comunal de El Pinar.',
      byHost: true,
    ),
  ],
);

void main() {
  group(ActaPage, () {
    testWidgets("follows the member's ronda's acta", (tester) async {
      final appBloc = _MockAppBloc();
      final repository = _MockOrganiserRepository();
      when(() => appBloc.state).thenReturn(
        const AppState(
          status: AppStatus.authenticated,
          user: User(id: 'demo-uid'),
        ),
      );
      when(() => repository.watchActa('ronda-1'))
          .thenAnswer((_) => Stream.value(_acta));

      await tester.pumpApp(
        RepositoryProvider<OrganiserRepository>.value(
          value: repository,
          child: BlocProvider<AppBloc>.value(
            value: appBloc,
            child: const ActaPage(rondaId: 'ronda-1'),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Mirta eligió: al Salón Comunal de El Pinar.'),
        findsOneWidget,
      );
      expect(ActaPage.location('ronda 1'), '/acta/ronda%201');
    });
  });

  group(ActaView, () {
    late ActaCubit cubit;

    setUp(() {
      cubit = _MockActaCubit();
      when(cubit.reportTapped).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, ActaState state) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(value: cubit, child: const ActaView()),
      );
    }

    testWidgets('waits while it reads', (tester) async {
      await pump(tester, const ActaState());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('a line a fixed rule decided says so', (tester) async {
      await pump(
        tester,
        ActaState(
          status: ActaStatus.ready,
          acta: Acta(
            week: '2026-W45',
            lines: [
              ActaLine(
                id: 'c',
                at: DateTime(2026, 11, 2),
                summary:
                    'Este mes abre Jorge y cierra Ana. Así toca por turno.',
                byHost: false,
                byRule: true,
              ),
            ],
          ),
        ),
      );

      expect(find.textContaining('Regla fija'), findsOneWidget);
    });

    testWidgets('offers to read it again when it failed', (tester) async {
      await pump(tester, const ActaState(status: ActaStatus.failure));

      await tester.tap(find.text('Probar de nuevo'));

      verify(cubit.subscribe).called(1);
    });

    testWidgets("shows the week's lines, the closing line and the report", (
      tester,
    ) async {
      await pump(tester, ActaState(status: ActaStatus.ready, acta: _acta));

      expect(find.text('Lo que hizo el programa'), findsOneWidget);
      expect(
        find.text(
          'Miró el pronóstico del jueves 5/11 a las 16:00: lluvia 80%.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Lo decidió quien abre'), findsOneWidget);
      expect(
        find.text('No leyó mensajes de nadie ni mandó nada fuera de horario.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Algo estuvo mal'));

      verify(cubit.reportTapped).called(1);
    });

    testWidgets('an empty week says so and has nothing to report', (
      tester,
    ) async {
      await pump(tester, const ActaState(status: ActaStatus.ready));

      expect(
        find.text('Esta semana el programa no hizo nada todavía.'),
        findsOneWidget,
      );
      final report = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Algo estuvo mal'),
      );
      expect(report.onPressed, isNull);
    });

    testWidgets('thanks the member once it is recorded', (tester) async {
      await pump(
        tester,
        ActaState(
          status: ActaStatus.ready,
          acta: _acta,
          report: ActaReport.sent,
        ),
      );

      expect(find.text('Gracias. Lo vamos a mirar.'), findsOneWidget);
      expect(find.text('Algo estuvo mal'), findsNothing);
    });

    testWidgets('says when it was not saved', (tester) async {
      await pump(
        tester,
        ActaState(
          status: ActaStatus.ready,
          acta: _acta,
          report: ActaReport.failed,
        ),
      );

      expect(find.text('No se guardó. Probá de nuevo.'), findsOneWidget);
    });
  });
}
