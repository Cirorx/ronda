import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/push/push.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockPushCubit extends MockCubit<PushState> implements PushCubit;

void main() {
  group(PushPrompt, () {
    late PushCubit cubit;

    setUp(() {
      cubit = _MockPushCubit();
      when(() => cubit.allowTapped()).thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester,
      PushStatus status, {
      Locale locale = rioplatense,
    }) {
      when(() => cubit.state).thenReturn(PushState(status: status));
      return tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: PushPrompt()),
        ),
        locale: locale,
      );
    }

    group('renders', () {
      testWidgets('the ask, what Ronda sends and both buttons', (tester) async {
        await pump(tester, PushStatus.offered);

        expect(find.text('¿Te avisamos los martes?'), findsOneWidget);
        expect(find.text('Uno por semana, el martes a las 19'), findsOneWidget);
        expect(find.text('Algún otro solo si cambia algo'), findsOneWidget);
        expect(
          find.text('Nunca de noche: solo entre las 9 y las 21.'),
          findsOneWidget,
        );
        expect(find.text('Sí, avisame'), findsOneWidget);
        expect(find.text('Ahora no'), findsOneWidget);
      });

      testWidgets('in English', (tester) async {
        await pump(tester, PushStatus.offered, locale: const Locale('en'));

        expect(find.text('Shall we let you know on Tuesdays?'), findsOneWidget);
        expect(find.text('Yes, let me know'), findsOneWidget);
      });

      testWidgets('how to turn them on when the phone refused, as a live '
          'region', (tester) async {
        final handle = tester.ensureSemantics();
        await pump(tester, PushStatus.blocked);

        final hint = find.textContaining('prendelos en los ajustes');
        expect(hint, findsOneWidget);
        expect(tester.getSemantics(hint), isSemantics(isLiveRegion: true));
        expect(find.text('Sí, avisame'), findsNothing);
        expect(find.text('Entendido'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('the buttons disabled while the system asks', (tester) async {
        await pump(tester, PushStatus.requesting);

        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed,
          isNull,
        );
      });

      for (final status in [
        PushStatus.checking,
        PushStatus.allowed,
        PushStatus.dismissed,
      ]) {
        testWidgets('nothing while $status', (tester) async {
          await pump(tester, status);

          expect(find.byType(Card), findsNothing);
        });
      }

      testWidgets('its buttons under the identifiers Maestro taps', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pump(tester, PushStatus.offered);

        for (final (identifier, label) in [
          (PushPrompt.allowIdentifier, 'Sí, avisame'),
          (PushPrompt.laterIdentifier, 'Ahora no'),
        ]) {
          expect(
            tester.getSemantics(find.bySemanticsIdentifier(identifier)),
            isSemantics(
              identifier: identifier,
              label: label,
              isButton: true,
              hasTapAction: true,
            ),
          );
        }
        expect(find.bySemanticsIdentifier(PushPrompt.identifier), findsOne);
        handle.dispose();
      });

      testWidgets('buttons of at least 48 dp', (tester) async {
        await pump(tester, PushStatus.offered);

        for (final button in [
          find.byType(FilledButton),
          find.byType(TextButton),
        ]) {
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        }
      });
    });

    group('calls', () {
      testWidgets('allowTapped on "Sí, avisame"', (tester) async {
        await pump(tester, PushStatus.offered);

        await tester.tap(find.text('Sí, avisame'));

        verify(() => cubit.allowTapped()).called(1);
      });

      testWidgets('dismissed on "Ahora no"', (tester) async {
        await pump(tester, PushStatus.offered);

        await tester.tap(find.text('Ahora no'));

        verify(() => cubit.dismissed()).called(1);
      });

      testWidgets('dismissed on "Entendido"', (tester) async {
        await pump(tester, PushStatus.blocked);

        await tester.tap(find.text('Entendido'));

        verify(() => cubit.dismissed()).called(1);
      });
    });
  });
}
