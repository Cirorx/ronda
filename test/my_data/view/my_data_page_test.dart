import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/my_data/my_data.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockMyDataCubit extends MockCubit<MyDataState> implements MyDataCubit;

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockProfileRepository extends Mock implements ProfileRepository;

class _MockNeedsRepository extends Mock implements NeedsRepository;

class _MockRondaRepository extends Mock implements RondaRepository;

// Invented demo data.
final _profile = Profile(
  firstName: 'Marta',
  ageBand: AgeBand.sixties,
  barrio: Barrio.cordon,
  pretexts: const {Pretext.mate},
  slots: {const Slot(SlotDay.saturday, SlotBand.afternoon)},
  brings: const {Bring.termo},
);

void main() {
  group(MyDataPage, () {
    testWidgets('reads the signed-in member and shows their answers', (
      tester,
    ) async {
      final appBloc = _MockAppBloc();
      whenListen(
        appBloc,
        const Stream<AppState>.empty(),
        initialState: const AppState(
          status: AppStatus.authenticated,
          user: User(id: 'demo-uid'),
        ),
      );
      final profiles = _MockProfileRepository();
      final rondas = _MockRondaRepository();
      when(() => profiles.watchProfile('demo-uid'))
          .thenAnswer((_) => Stream.value(_profile));
      when(() => rondas.watchThisWeek('demo-uid'))
          .thenAnswer((_) => Stream.value(null));

      await tester.pumpApp(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ProfileRepository>.value(value: profiles),
            RepositoryProvider<NeedsRepository>.value(
              value: _MockNeedsRepository(),
            ),
            RepositoryProvider<RondaRepository>.value(value: rondas),
          ],
          child: BlocProvider<AppBloc>.value(
            value: appBloc,
            child: const MyDataPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis datos'), findsOneWidget);
      expect(find.byType(MyDataView), findsOneWidget);
      expect(find.text('Marta'), findsOneWidget);
    });
  });

  group(MyDataView, () {
    late MyDataCubit cubit;

    setUp(() {
      cubit = _MockMyDataCubit();
      when(cubit.load).thenAnswer((_) async {});
      when(cubit.save).thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester,
      MyDataState state, {
      Locale locale = rioplatense,
    }) async {
      // A fresh tree per state: the view selects from the cubit's stream.
      await tester.pumpWidget(const SizedBox());
      whenListen(cubit, const Stream<MyDataState>.empty(), initialState: state);
      await tester.pumpApp(
        BlocProvider.value(value: cubit, child: const MyDataView()),
        locale: locale,
        // Tall enough to hold the whole form.
        size: const Size(400, 2600),
      );
    }

    final loaded = MyDataState.fromProfile(_profile, seated: false);

    testWidgets('says it is reading, then that it could not', (tester) async {
      await pump(tester, const MyDataState());
      expect(find.text('Buscando tus datos…'), findsOneWidget);

      await pump(tester, const MyDataState(status: MyDataStatus.loadFailure));
      await tester.tap(find.text('Probar de nuevo'));
      verify(cubit.load).called(1);
    });

    testWidgets('shows casa without trabajo, and what others see', (
      tester,
    ) async {
      await pump(tester, loaded);

      expect(find.textContaining('Los demás ven solo'), findsOneWidget);
      expect(find.text('Casa'), findsOneWidget);
      expect(find.text('Cordón'), findsOneWidget);
      expect(find.text('Hasta unas 22 cuadras'), findsOneWidget);
      expect(find.text('Agregar trabajo'), findsOneWidget);
      expect(find.text('Trabajo'), findsNothing);
    });

    testWidgets('switches casa and trabajo neighbours and takes trabajo out', (
      tester,
    ) async {
      await pump(
        tester,
        loaded.copyWith(work: () => const Anchor(barrio: Barrio.centro)),
      );

      await tester.tap(
        find.bySemanticsIdentifier(
          '${AnchorSection.neighboursIdentifier}.home',
        ),
      );
      verify(() => cubit.homeNeighboursChanged(neighbours: true)).called(1);
      await tester.tap(
        find.bySemanticsIdentifier(
          '${AnchorSection.neighboursIdentifier}.work',
        ),
      );
      verify(() => cubit.workNeighboursChanged(neighbours: true)).called(1);
      await tester.tap(find.text('Sacar trabajo'));
      verify(cubit.workRemoved).called(1);
    });

    testWidgets('picks trabajo on a sheet that leaves casa out', (
      tester,
    ) async {
      await pump(tester, loaded);
      await tester.tap(find.text('Agregar trabajo'));
      await tester.pumpAndSettle();
      expect(find.text('Elegí el barrio'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'centro');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Cordón'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Centro'));
      await tester.pumpAndSettle();

      verify(() => cubit.workChanged(Barrio.centro)).called(1);
      expect(find.text('Elegí el barrio'), findsNothing);
    });

    testWidgets('changes casa and trabajo from their «Cambiar»', (
      tester,
    ) async {
      await pump(
        tester,
        loaded.copyWith(work: () => const Anchor(barrio: Barrio.centro)),
      );

      for (final (kind, barrio) in [('home', 'Palermo'), ('work', 'Aguada')]) {
        await tester.tap(
          find.bySemanticsIdentifier('${AnchorSection.changeIdentifier}.$kind'),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, barrio);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, barrio));
        await tester.pumpAndSettle();
      }

      verify(() => cubit.homeChanged(Barrio.palermo)).called(1);
      verify(() => cubit.workChanged(Barrio.aguada)).called(1);
    });

    testWidgets('tells a seated member a new barrio counts from the next '
        'grouping', (tester) async {
      final seated = MyDataState.fromProfile(_profile, seated: true);
      await pump(
        tester,
        seated.copyWith(home: const Anchor(barrio: Barrio.centro)),
      );

      expect(find.textContaining('seguís en ella'), findsOneWidget);

      await pump(tester, seated);
      expect(find.textContaining('seguís en ella'), findsNothing);
    });

    testWidgets('edits every answer through the pickers', (tester) async {
      await pump(tester, loaded);

      await tester.enterText(find.byType(TextFormField), 'Inés');
      verify(() => cubit.firstNameChanged('Inés')).called(1);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Setenta y pico'));
      verify(() => cubit.ageBandChanged(AgeBand.seventies)).called(1);
      await tester.tap(find.text('Guardar'));
      verify(cubit.save).called(1);
    });

    testWidgets('says what is missing, saving, saved and failed', (
      tester,
    ) async {
      for (final (state, line) in [
        (loaded.copyWith(brings: const {}), 'Elegí al menos una opción'),
        (loaded.copyWith(status: MyDataStatus.saving), 'Guardando…'),
        (loaded.copyWith(status: MyDataStatus.saved), 'Listo, guardado.'),
        (
          loaded.copyWith(status: MyDataStatus.saveFailure),
          'No pudimos guardar',
        ),
      ]) {
        await pump(tester, state);
        expect(find.textContaining(line), findsOneWidget);
      }
      expect(loaded.status.isUnderway, isFalse);
    });

    testWidgets('in English', (tester) async {
      await pump(tester, loaded, locale: const Locale('en'));

      expect(find.text('My details'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Neighbouring barrios too'), findsOneWidget);
    });
  });
}
