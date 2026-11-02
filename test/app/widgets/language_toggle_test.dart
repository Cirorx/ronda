import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockLanguageCubit extends MockCubit<LanguageState>
    implements LanguageCubit;

void main() {
  group(LanguageToggle, () {
    late LanguageCubit cubit;

    setUpAll(() => registerFallbackValue(AppLanguage.spanish));

    setUp(() {
      cubit = _MockLanguageCubit();
      when(() => cubit.state).thenReturn(const LanguageState());
      when(() => cubit.languagePicked(any())).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, {Locale locale = rioplatense}) =>
        tester.pumpApp(
          BlocProvider.value(value: cubit, child: const LanguageToggle()),
          locale: locale,
        );

    testWidgets('offers English while the app speaks Spanish', (tester) async {
      await pump(tester);

      await tester.tap(find.bySemanticsIdentifier(LanguageToggle.identifier));

      expect(find.text('English'), findsOneWidget);
      verify(() => cubit.languagePicked(AppLanguage.english)).called(1);
    });

    testWidgets('can leave the icon out', (tester) async {
      await tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const LanguageToggle(showIcon: false),
        ),
      );

      expect(find.byIcon(Icons.translate), findsNothing);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('offers Español while the app speaks English', (tester) async {
      await pump(tester, locale: const Locale('en'));

      await tester.tap(find.text('Español'));

      verify(() => cubit.languagePicked(AppLanguage.spanish)).called(1);
    });
  });

  group('LanguageLabels', () {
    test('names each choice, and the phone when none was picked', () {
      final es = lookupAppLocalizations(rioplatense);

      expect(es.languageName(AppLanguage.spanish), 'Español');
      expect(es.languageName(AppLanguage.english), 'English');
      expect(es.languageName(null), 'Como el teléfono');
    });
  });

  group('AppLanguageLocale', () {
    test('pins rioplatense Spanish, English, or nothing', () {
      expect(AppLanguage.spanish.locale, const Locale('es', '419'));
      expect(AppLanguage.english.locale, const Locale('en'));
      expect((null as AppLanguage?).locale, isNull);
    });
  });
}
