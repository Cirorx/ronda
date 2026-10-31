import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda/my_ronda/widgets/handoff_ask.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockThisWeekCubit extends MockCubit<ThisWeekState>
    implements ThisWeekCubit;

void main() {
  group(HandoffAskSection, () {
    late ThisWeekCubit cubit;

    setUp(() {
      cubit = _MockThisWeekCubit();
      when(() => cubit.handoffAnswered(yes: any(named: 'yes')))
          .thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, ThisWeekState state) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: HandoffAskSection(ask: MyRondaFixtures.handoffAsk),
          ),
        ),
      );
    }

    testWidgets('asks the cola, with what opening is', (tester) async {
      await pump(tester, const ThisWeekState());

      expect(find.text('¿Abrís vos?'), findsOneWidget);
      expect(
        find.text('Mirta no puede el sábado. ¿Abrís vos?'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Abrir es llegar diez minutos antes, a las 15:50, y saludar a los '
          'que van llegando. Nada más.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('both answers go through the cubit, felt as commits', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await pump(tester, const ThisWeekState());

      await tester.tap(find.text('Sí, abro yo'));
      await tester.tap(find.text('Hoy no puedo'));

      expect(haptics, [commitHaptic, commitHaptic]);

      verify(() => cubit.handoffAnswered(yes: true)).called(1);
      verify(() => cubit.handoffAnswered(yes: false)).called(1);
    });

    testWidgets('waits while an answer is on its way', (tester) async {
      await pump(tester, const ThisWeekState(acting: true));

      await tester.tap(find.text('Sí, abro yo'));

      verifyNever(() => cubit.handoffAnswered(yes: any(named: 'yes')));
    });

    testWidgets('says when someone else opens it', (tester) async {
      await pump(
        tester,
        const ThisWeekState(actionFailure: HostsFailureReason.passed),
      );

      expect(find.text('Ya no hace falta: alguien más abre.'), findsOneWidget);
    });

    testWidgets('says when an answer was not saved', (tester) async {
      await pump(
        tester,
        const ThisWeekState(actionFailure: HostsFailureReason.other),
      );

      expect(find.text('No se guardó. Probá de nuevo.'), findsOneWidget);
    });

    testWidgets('reads out why an answer was not saved', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const ThisWeekState(actionFailure: HostsFailureReason.passed),
      );

      expect(
        tester.getSemantics(find.text('Ya no hace falta: alguien más abre.')),
        isSemantics(isLiveRegion: true),
      );
      handle.dispose();
    });
  });
}
