import 'package:bloc_test/bloc_test.dart';
import 'package:contact_repository/contact_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/acta/acta.dart';
import 'package:ronda/my_ronda/cubit/bench_offer_cubit.dart';
import 'package:ronda/my_ronda/cubit/seguimos_cubit.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda/my_ronda/cubit/waiting_cubit.dart';
import 'package:ronda/my_ronda/my_ronda.dart';
import 'package:ronda/my_ronda/widgets/this_week_card.dart';
import 'package:ronda/my_ronda/widgets/who_is_going.dart';
import 'package:ronda/push/push.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

class _MockContactRepository extends Mock implements ContactRepository;

class _MockPushCubit extends MockCubit<PushState> implements PushCubit;

class _MockThisWeekCubit extends MockCubit<ThisWeekState>
    implements ThisWeekCubit;

class _MockSeguimosCubit extends MockCubit<SeguimosState>
    implements SeguimosCubit;

class _MockBenchOfferCubit extends MockCubit<BenchOfferState>
    implements BenchOfferCubit;

class _MockWaitingCubit extends MockCubit<WaitingState> implements WaitingCubit;

void main() {
  group('$MyRondaView on wide windows', () {
    late PushCubit pushCubit;
    late ThisWeekCubit thisWeekCubit;
    late SeguimosCubit seguimosCubit;
    late BenchOfferCubit benchOfferCubit;
    late WaitingCubit waitingCubit;
    late RondaRepository rondaRepository;
    late ContactRepository contactRepository;

    final ready = ThisWeekState(
      status: ThisWeekStatus.ready,
      week: MyRondaFixtures.week(),
    );

    setUp(() {
      rondaRepository = _MockRondaRepository();
      contactRepository = _MockContactRepository();
      when(() => rondaRepository.watchBuddyAsk(any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => rondaRepository.buddyOptions(any())).thenAnswer(
        (_) async => const BuddyOptions(due: false, chosen: false, choices: []),
      );
      when(contactRepository.canOpenWhatsApp).thenAnswer((_) async => false);
      pushCubit = _MockPushCubit();
      thisWeekCubit = _MockThisWeekCubit();
      seguimosCubit = _MockSeguimosCubit();
      benchOfferCubit = _MockBenchOfferCubit();
      waitingCubit = _MockWaitingCubit();
      when(() => benchOfferCubit.state)
          .thenReturn(const BenchOfferState(status: BenchOfferCardStatus.none));
      when(() => waitingCubit.state)
          .thenReturn(const WaitingState(status: WaitingCardStatus.none));
      when(() => seguimosCubit.state)
          .thenReturn(const SeguimosState(status: SeguimosCardStatus.none));
      when(() => pushCubit.state)
          .thenReturn(const PushState(status: PushStatus.dismissed));
      when(() => thisWeekCubit.state).thenReturn(ready);
    });

    Future<void> pump(
      WidgetTester tester, {
      Size size = desktopSize,
      double textScale = 1,
    }) async {
      await tester.pumpApp(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider.value(value: rondaRepository),
            RepositoryProvider.value(value: contactRepository),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: pushCubit),
              BlocProvider.value(value: thisWeekCubit),
              BlocProvider.value(value: seguimosCubit),
              BlocProvider.value(value: benchOfferCubit),
              BlocProvider.value(value: waitingCubit),
            ],
            child: const MyRondaView(uid: MyRondaFixtures.uid),
          ),
        ),
        size: size,
        textScale: textScale,
      );
      await tester.pumpAndSettle();
    }

    Finder onCard(Finder finder) =>
        find.descendant(of: find.byType(ThisWeekCard), matching: finder);

    testWidgets('keeps "Quiénes van" on the card at ${phoneSize.width} px', (
      tester,
    ) async {
      await pump(tester, size: phoneSize);

      expect(onCard(find.byType(WhoIsGoing)), findsOneWidget);
      expect(find.byType(PaperColumns), findsNothing);
      expect(find.byType(ReadableColumn), findsNothing);
      expect(find.byType(RondaObjectIcon), findsNothing);
    });

    testWidgets('keeps one readable column at ${tabletSize.width} px', (
      tester,
    ) async {
      await pump(tester, size: tabletSize);

      expect(onCard(find.byType(WhoIsGoing)), findsOneWidget);
      expect(find.byType(PaperColumns), findsNothing);
      expect(
        tester.getSize(find.byType(ThisWeekCard)).width,
        lessThanOrEqualTo(WindowSize.readableWidth),
      );
    });

    group('at ${desktopSize.width} px', () {
      testWidgets('puts "Quiénes van" and the acta beside the card', (
        tester,
      ) async {
        await pump(tester);

        expect(find.byType(PaperColumns), findsOneWidget);
        expect(onCard(find.byType(WhoIsGoing)), findsNothing);
        expect(find.byType(WhoIsGoing), findsOneWidget);
        final card = tester.getRect(find.byType(ThisWeekCard));
        expect(
          tester.getRect(find.byType(WhoIsGoing)).left,
          greaterThan(card.right),
        );
        expect(
          tester.getRect(find.byType(ActaLink)).left,
          greaterThan(card.right),
        );
        expect(find.text('Raúl'), findsOneWidget);
      });

      testWidgets('draws what each neighbour brings', (tester) async {
        await pump(tester);

        expect(
          find.descendant(
            of: find.byType(WhoIsGoing),
            matching: find.byType(RondaObjectIcon),
          ),
          findsOneWidget,
        );
      });

      testWidgets('has nothing beside the card before a group exists', (
        tester,
      ) async {
        when(() => thisWeekCubit.state)
            .thenReturn(const ThisWeekState(status: ThisWeekStatus.noGroup));
        await pump(tester);

        expect(find.byType(WhoIsGoing), findsNothing);
        expect(find.byType(ActaLink), findsNothing);
        expect(find.text('Todavía no tenés grupo'), findsOneWidget);
      });

      testWidgets('takes focus through the card before the side', (
        tester,
      ) async {
        await pump(tester);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();

        final card = tester.getRect(find.byType(ThisWeekCard));
        final reached = <bool>[];
        for (var i = 0; i < 6; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final box =
              FocusManager.instance.primaryFocus!.context!.findRenderObject()!
                  as RenderBox;
          reached.add(
            box.localToGlobal(box.size.center(Offset.zero)).dx < card.right,
          );
        }
        // "Voy" and "Esta no" on the card, then the acta's link beside it.
        final firstSide = reached.indexOf(false);
        expect(firstSide, greaterThan(0));
        expect(reached.take(firstSide), everyElement(isTrue));
      });

      testWidgets('holds at 200% text', (tester) async {
        await pump(tester, textScale: 2);

        expect(tester.takeException(), isNull);
        expect(find.byType(WhoIsGoing), findsOneWidget);
        // Large text keeps the words and drops the drawings.
        expect(find.byType(RondaObjectIcon), findsNothing);
      });
    });
  });
}
