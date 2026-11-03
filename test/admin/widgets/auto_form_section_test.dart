import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockAutoFormCubit extends MockCubit<AutoFormState>
    implements AutoFormCubit;

void main() {
  group(AutoFormSection, () {
    late AutoFormCubit cubit;

    const ready = AutoFormState(
      status: AutoFormStatus.ready,
      settings: AutoFormSettings(enabled: true, holdMinutes: 60),
    );

    setUp(() {
      cubit = _MockAutoFormCubit();
      when(() => cubit.enabledToggled(enabled: any(named: 'enabled')))
          .thenAnswer((_) async {});
      when(cubit.holdSaved).thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester,
      AutoFormState state, {
      Locale locale = rioplatense,
    }) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const Scaffold(
            body: SingleChildScrollView(child: AutoFormSection()),
          ),
        ),
        locale: locale,
      );
    }

    Finder save() => find.widgetWithText(OutlinedButton, 'Guardar');

    testWidgets('says what it does, with the switch on and the hold', (
      tester,
    ) async {
      await pump(tester, ready);

      expect(find.text('Rondas que se arman solas'), findsOneWidget);
      expect(find.textContaining('Cada hora el programa'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(find.widgetWithText(TextFormField, '60'), findsOneWidget);
    });

    testWidgets('turns it off on a tap', (tester) async {
      await pump(tester, ready);

      await tester.tap(find.text('Que se armen solas'));

      verify(() => cubit.enabledToggled(enabled: false)).called(1);
    });

    testWidgets('passes what is typed and saves it', (tester) async {
      await pump(tester, ready);

      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(save());

      verify(() => cubit.holdChanged('0')).called(1);
      verify(cubit.holdSaved).called(1);
    });

    testWidgets('a hold out of range says so and cannot be saved', (
      tester,
    ) async {
      await pump(tester, ready.copyWith(holdDraft: '5000'));

      expect(find.text('De 0 a 1440.'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(save()).onPressed, isNull);
    });

    testWidgets('waits while a change is saving', (tester) async {
      await pump(tester, ready.copyWith(saving: true));

      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      expect(tester.widget<OutlinedButton>(save()).onPressed, isNull);
    });

    testWidgets('a failed save', (tester) async {
      await pump(tester, ready.copyWith(saveFailed: true));

      expect(find.byType(NoteBanner), findsOneWidget);
    });

    testWidgets('a failed read', (tester) async {
      await pump(tester, const AutoFormState(status: AutoFormStatus.failure));

      expect(find.text('No se pudo leer la configuración.'), findsOneWidget);
    });

    testWidgets('the read', (tester) async {
      await pump(tester, const AutoFormState());

      expect(find.byType(LoadingStatus), findsOneWidget);
    });

    testWidgets('in English', (tester) async {
      await pump(tester, ready, locale: const Locale('en'));

      expect(find.text('Rondas that form themselves'), findsOneWidget);
      expect(find.text('Minutes to stop it'), findsOneWidget);
    });
  });
}
