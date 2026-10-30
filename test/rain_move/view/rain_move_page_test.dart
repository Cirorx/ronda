import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:ronda/rain_move/rain_move.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockOrganiserRepository extends Mock implements OrganiserRepository;

class _MockRainMoveCubit extends MockCubit<RainMoveState>
    implements RainMoveCubit;

const _covered = RainOption(
  choice: MoveChoice.covered,
  label: 'Al Salón Comunal de El Pinar',
  message:
      'Por la lluvia, el jueves nos vemos en el Salón Comunal de El Pinar a '
      'las 16:00. Lo decidió Mirta.',
);
const _asIs = RainOption(
  choice: MoveChoice.asIs,
  label: 'Vamos igual',
  message: 'Puede llover, pero el jueves vamos igual. Lo decidió Mirta.',
);

RainMove _move({
  RainMoveStatus status = RainMoveStatus.pending,
  bool standIn = false,
  MoveChoice? choice,
  int? sent,
}) => RainMove(
  title: 'El jueves puede llover',
  forecast:
      'Jueves 16:00 · lluvia 80%. Ráfagas de 50 km/h. Pronóstico de '
      'Open-Meteo.',
  options: const [_covered, _asIs],
  recipients: 5,
  deadline: DateTime(2026, 11, 4, 21),
  status: status,
  standIn: standIn,
  choice: choice,
  sent: sent,
);

void main() {
  group(RainMovePage, () {
    testWidgets('follows the proposal of its ronda and week', (tester) async {
      final repository = _MockOrganiserRepository();
      when(() => repository.watchMove('ronda-1', '2026-W45'))
          .thenAnswer((_) => Stream.value(_move()));

      await tester.pumpApp(
        RepositoryProvider<OrganiserRepository>.value(
          value: repository,
          child: const RainMovePage(rondaId: 'ronda-1', week: '2026-W45'),
        ),
      );
      await tester.pump();

      expect(find.text('El jueves puede llover'), findsOneWidget);
      expect(
        RainMovePage.location('ronda 1', '2026-W45'),
        '/lluvia/ronda%201/2026-W45',
      );
    });
  });

  group(RainMoveView, () {
    late RainMoveCubit cubit;

    setUp(() {
      cubit = _MockRainMoveCubit();
      when(cubit.sendTapped).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, RainMoveState state) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(value: cubit, child: const RainMoveView()),
      );
    }

    testWidgets('waits while it reads', (tester) async {
      await pump(tester, const RainMoveState());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    for (final status in [
      RainMoveViewStatus.none,
      RainMoveViewStatus.forbidden,
    ]) {
      testWidgets('${status.name}: nothing to decide', (tester) async {
        await pump(tester, RainMoveState(status: status));

        expect(find.text('No hay nada para decidir.'), findsOneWidget);
      });
    }

    testWidgets('offers to read it again when it failed', (tester) async {
      await pump(
        tester,
        const RainMoveState(status: RainMoveViewStatus.failure),
      );

      await tester.tap(find.text('Probar de nuevo'));

      verify(cubit.subscribe).called(1);
    });

    testWidgets('shows the forecast and the options', (tester) async {
      await pump(
        tester,
        RainMoveState(status: RainMoveViewStatus.ready, move: _move()),
      );

      expect(find.text('El jueves puede llover'), findsOneWidget);
      expect(
        find.text(
          'Jueves 16:00 · lluvia 80%. Ráfagas de 50 km/h. Pronóstico de '
          'Open-Meteo.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Lo que elijas les llega a los 5 en un solo mensaje. Si no '
          'contestás antes de las 21, queda como está.',
        ),
        findsOneWidget,
      );
      expect(find.text('Mandarlo'), findsNothing);

      await tester.tap(find.text('Al Salón Comunal de El Pinar'));
      await tester.tap(find.text('Vamos igual'));

      verify(() => cubit.optionTapped(MoveChoice.covered)).called(1);
      verify(() => cubit.optionTapped(MoveChoice.asIs)).called(1);
    });

    testWidgets('shows the exact message of the tapped option and sends it', (
      tester,
    ) async {
      await pump(
        tester,
        RainMoveState(
          status: RainMoveViewStatus.ready,
          move: _move(),
          selected: MoveChoice.covered,
        ),
      );

      expect(find.text('Les va a llegar, tal cual:'), findsOneWidget);
      expect(find.text(_covered.message), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Al Salón Comunal de El Pinar'),
        findsOneWidget,
      );
      await tester.tap(find.text('Al Salón Comunal de El Pinar'));
      await tester.scrollUntilVisible(find.text('Mandarlo'), 200);
      await tester.tap(find.text('Mandarlo'));

      verify(() => cubit.optionTapped(MoveChoice.covered)).called(1);
      verify(cubit.sendTapped).called(1);
    });

    testWidgets('waits while it sends', (tester) async {
      await pump(
        tester,
        RainMoveState(
          status: RainMoveViewStatus.ready,
          move: _move(),
          selected: MoveChoice.asIs,
          sending: RainMoveSending.sending,
        ),
      );
      await tester.scrollUntilVisible(find.text('Mandando…'), 200);

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Mandando…'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('says when it was not sent', (tester) async {
      await pump(
        tester,
        RainMoveState(
          status: RainMoveViewStatus.ready,
          move: _move(),
          selected: MoveChoice.asIs,
          sending: RainMoveSending.failed,
        ),
      );
      await tester.scrollUntilVisible(find.text('Mandarlo'), 200);

      expect(find.text('No se mandó. Probá de nuevo.'), findsOneWidget);
    });

    testWidgets('a stand-in host is told why they are asked', (tester) async {
      await pump(
        tester,
        RainMoveState(
          status: RainMoveViewStatus.ready,
          move: _move(standIn: true),
        ),
      );

      expect(
        find.text(
          'Todavía nadie abre esta ronda, así que te lo preguntamos a vos.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('once decided, says what and how many it reached', (
      tester,
    ) async {
      await pump(
        tester,
        RainMoveState(
          status: RainMoveViewStatus.ready,
          move: _move(
            status: RainMoveStatus.decided,
            choice: MoveChoice.asIs,
            sent: 5,
          ),
        ),
      );

      expect(find.text('Elegiste: Vamos igual.'), findsOneWidget);
      expect(find.text('Listo. Les llegó a 5.'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('a decision of an unknown option still says it went', (
      tester,
    ) async {
      await pump(
        tester,
        RainMoveState(
          status: RainMoveViewStatus.ready,
          move: _move(status: RainMoveStatus.decided),
        ),
      );

      expect(find.text('Listo. No le llegó a nadie.'), findsOneWidget);
    });

    for (final (move, sending) in [
      (_move(status: RainMoveStatus.expired), RainMoveSending.idle),
      (_move(), RainMoveSending.late),
    ]) {
      testWidgets('past the deadline it stays as it is', (tester) async {
        await pump(
          tester,
          RainMoveState(
            status: RainMoveViewStatus.ready,
            move: move,
            sending: sending,
          ),
        );

        expect(find.text('Ya pasó la hora: queda como está.'), findsOneWidget);
        expect(find.byType(OutlinedButton), findsNothing);
      });
    }
  });
}
