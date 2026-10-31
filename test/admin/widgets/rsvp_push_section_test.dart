import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockRsvpPushCubit extends MockCubit<RsvpPushState>
    implements RsvpPushCubit;

void main() {
  group(RsvpPushSection, () {
    late RsvpPushCubit cubit;

    setUp(() {
      cubit = _MockRsvpPushCubit();
      when(cubit.sendTapped).thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester,
      RsvpPushState state, {
      Locale locale = rioplatense,
    }) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: RsvpPushSection()),
        ),
        locale: locale,
      );
    }

    Finder button(String label) => find.widgetWithText(OutlinedButton, label);

    testWidgets('says what it does and sends it on a tap', (tester) async {
      await pump(tester, const RsvpPushState());

      expect(find.text('El ¿Venís? de esta semana'), findsOneWidget);
      await tester.tap(button('Mandarlo ahora'));

      verify(cubit.sendTapped).called(1);
    });

    testWidgets('sends as a commit, with one light tap', (tester) async {
      final haptics = recordHaptics(tester);
      await pump(tester, const RsvpPushState());

      await tester.tap(button('Mandarlo ahora'));

      expect(haptics, ['HapticFeedbackType.lightImpact']);
    });

    testWidgets('its title as a heading', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const RsvpPushState());

      expect(
        tester.getSemantics(find.text('El ¿Venís? de esta semana')),
        isSemantics(isHeader: true),
      );
      semantics.dispose();
    });

    testWidgets('waits while it sends, with nothing felt', (tester) async {
      final haptics = recordHaptics(tester);
      await pump(tester, const RsvpPushState(status: RsvpPushStatus.sending));

      expect(
        tester.widget<OutlinedButton>(button('Mandando…')).onPressed,
        isNull,
      );
      await tester.tap(button('Mandando…'), warnIfMissed: false);
      expect(haptics, isEmpty);
    });

    testWidgets('says how many phones it reached', (tester) async {
      await pump(
        tester,
        const RsvpPushState(
          status: RsvpPushStatus.sent,
          result: RsvpPushResult(pushed: 1, messages: 5, already: 0, held: 0),
        ),
      );

      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester.getSemantics(find.text('Llegó a 5 teléfonos.')),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('says when it was sent already or held at night', (
      tester,
    ) async {
      await pump(
        tester,
        const RsvpPushState(
          status: RsvpPushStatus.sent,
          result: RsvpPushResult(pushed: 0, messages: 0, already: 1, held: 2),
        ),
      );

      expect(
        find.text(
          'No llegó a ningún teléfono. 1 ronda ya lo tenía esta semana. '
          'Frenado: fuera de horario. Sale entre las 9 y las 21.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says it failed', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const RsvpPushState(status: RsvpPushStatus.failed));

      expect(find.byType(NoteBanner), findsOneWidget);
      expect(
        tester.getSemantics(find.text('No se pudo. Probá de nuevo.')),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('reads in English', (tester) async {
      await pump(tester, const RsvpPushState(), locale: const Locale('en'));

      expect(find.text('Send it now'), findsOneWidget);
    });
  });
}
