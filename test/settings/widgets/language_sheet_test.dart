import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/settings/settings.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockLanguageCubit extends MockCubit<LanguageState>
    implements LanguageCubit;

void main() {
  group(LanguageSheet, () {
    late LanguageCubit cubit;

    setUpAll(() => registerFallbackValue(AppLanguage.spanish));

    setUp(() {
      cubit = _MockLanguageCubit();
      when(() => cubit.state)
          .thenReturn(const LanguageState(language: AppLanguage.spanish));
      when(() => cubit.languagePicked(any())).thenAnswer((_) async {});
    });

    Future<void> open(WidgetTester tester) async {
      await tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => LanguageSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists the three choices and marks the picked one', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Como el teléfono'), findsOneWidget);
      expect(find.text('Español'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Español'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
    });

    testWidgets('goes back to the phone language and closes', (tester) async {
      await open(tester);

      await tester.tap(
        find.bySemanticsIdentifier('${LanguageSheet.identifier}.phone'),
      );
      await tester.pumpAndSettle();

      verify(() => cubit.languagePicked(null)).called(1);
      expect(find.byType(LanguageSheet), findsNothing);
    });
  });
}
