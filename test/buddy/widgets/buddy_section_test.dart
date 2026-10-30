import 'package:bloc_test/bloc_test.dart';
import 'package:contact_repository/contact_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/buddy/buddy.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockBuddyCubit extends MockCubit<BuddyState> implements BuddyCubit;

class _MockRondaRepository extends Mock implements RondaRepository;

class _MockContactRepository extends Mock implements ContactRepository;

const _mirta = SetupMember(uid: 'demo-101', firstName: 'Mirta');
const _jorge = SetupMember(uid: 'demo-102', firstName: 'Jorge');
const _ask = BuddyAsk(
  rondaId: 'r1',
  misses: [BuddyMiss(firstName: 'Graciela', dayId: 'thu')],
);

BuddyState _ready({
  bool chosen = false,
  SetupMember? buddy,
  bool due = true,
  String? selected,
  bool changing = false,
  bool saveFailed = false,
  BuddyAsk? ask,
  bool canWhatsApp = true,
}) => BuddyState(
  status: BuddyStatus.ready,
  options: BuddyOptions(
    due: due,
    chosen: chosen,
    choices: const [_mirta, _jorge],
    buddy: buddy,
  ),
  selected: selected,
  changing: changing,
  saveFailed: saveFailed,
  ask: ask,
  canWhatsApp: canWhatsApp,
);

void main() {
  group(BuddySection, () {
    testWidgets('loads the options for its ronda', (tester) async {
      final rondas = _MockRondaRepository();
      final contacts = _MockContactRepository();
      when(() => rondas.watchBuddyAsk('demo-001'))
          .thenAnswer((_) => Stream.value(null));
      when(() => rondas.buddyOptions('r1')).thenAnswer(
        (_) async => const BuddyOptions(
          due: true,
          chosen: true,
          choices: [_mirta],
          buddy: _mirta,
        ),
      );
      when(contacts.canOpenWhatsApp).thenAnswer((_) async => false);

      await tester.pumpApp(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<RondaRepository>.value(value: rondas),
            RepositoryProvider<ContactRepository>.value(value: contacts),
          ],
          child: const Scaffold(
            body: BuddySection(rondaId: 'r1', uid: 'demo-001'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Si faltás sin avisar, le avisamos a Mirta. Nadie más se entera.',
        ),
        findsOneWidget,
      );
    });
  });

  group(BuddyView, () {
    late BuddyCubit cubit;

    setUp(() {
      cubit = _MockBuddyCubit();
      when(cubit.chooseTapped).thenAnswer((_) async {});
      when(cubit.notNowTapped).thenAnswer((_) async {});
      when(cubit.writeTapped).thenAnswer((_) async {});
      when(cubit.askClosed).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, BuddyState state) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const Scaffold(
            body: SingleChildScrollView(child: BuddyView()),
          ),
        ),
      );
    }

    testWidgets('shows nothing before the first meeting', (tester) async {
      await pump(tester, _ready(due: false));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows nothing while loading', (tester) async {
      await pump(tester, const BuddyState());
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('asks who to tell, by first name', (tester) async {
      await pump(tester, _ready());

      expect(
        find.text('Si un día faltás sin avisar, ¿a quién le avisamos?'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Elegí a alguien que ya tenga tu WhatsApp. Nadie más se entera, y '
          'no avisamos a tu familia.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Jorge'));
      verify(() => cubit.picked('demo-102')).called(1);

      await tester.tap(find.text('Elegir'));
      verifyNever(cubit.chooseTapped);
      await tester.tap(find.text('Ahora no'));
      verify(cubit.notNowTapped).called(1);
    });

    testWidgets('"Elegir" saves who is picked, and says when it failed', (
      tester,
    ) async {
      await pump(tester, _ready(selected: 'demo-102', saveFailed: true));

      expect(find.text('No se guardó. Probá de nuevo.'), findsOneWidget);
      await tester.tap(find.text('Elegir'));

      verify(cubit.chooseTapped).called(1);
    });

    testWidgets('says who was chosen, with a way to change it', (tester) async {
      await pump(tester, _ready(chosen: true, buddy: _jorge));
      expect(
        find.text(
          'Si faltás sin avisar, le avisamos a Jorge. Nadie más se entera.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cambiar'));
      verify(cubit.changeTapped).called(1);
    });

    testWidgets('says when nobody was chosen', (tester) async {
      await pump(tester, _ready(chosen: true));
      expect(
        find.text('Si faltás sin avisar, no le avisamos a nadie.'),
        findsOneWidget,
      );
      expect(find.text('Elegir a alguien'), findsOneWidget);
    });

    testWidgets('the list shows again while changing', (tester) async {
      await pump(tester, _ready(chosen: true, buddy: _jorge, changing: true));

      expect(find.text('Mirta'), findsOneWidget);
    });

    testWidgets('a buddy hears only a first name, and writes on WhatsApp', (
      tester,
    ) async {
      await pump(tester, _ready(due: false, ask: _ask));

      expect(
        find.text(
          'Graciela no vino el jueves. Te eligió a vos para estas cosas. '
          '¿Le escribís? Graciela no sabe que te avisamos.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Le escribo'));
      await tester.tap(find.text('Ahora no'));

      verify(cubit.writeTapped).called(1);
      verify(cubit.askClosed).called(1);
    });

    testWidgets('[Le escribo] hides where WhatsApp cannot open', (
      tester,
    ) async {
      await pump(tester, _ready(due: false, ask: _ask, canWhatsApp: false));

      expect(find.text('Le escribo'), findsNothing);
      expect(find.text('Ahora no'), findsOneWidget);
    });
  });
}
