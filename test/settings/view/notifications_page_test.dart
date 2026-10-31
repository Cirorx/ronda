import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/settings/settings.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockPushRepository extends Mock implements PushRepository;

class _MockNotificationsCubit extends MockCubit<NotificationsState>
    implements NotificationsCubit;

void main() {
  group(NotificationsPage, () {
    late AppBloc appBloc;
    late PushRepository pushRepository;

    setUp(() {
      appBloc = _MockAppBloc();
      pushRepository = _MockPushRepository();
      whenListen(
        appBloc,
        const Stream<AppState>.empty(),
        initialState: const AppState(
          status: AppStatus.authenticated,
          user: User(id: 'demo-uid'),
        ),
      );
      when(pushRepository.permission)
          .thenAnswer((_) async => PushPermission.notAsked);
    });

    testWidgets('reads the permission when it opens', (tester) async {
      await tester.pumpApp(
        RepositoryProvider.value(
          value: pushRepository,
          child: BlocProvider.value(
            value: appBloc,
            child: const NotificationsPage(),
          ),
        ),
      );
      await tester.pump();

      verify(pushRepository.permission).called(1);
      expect(find.text('Los avisos están apagados.'), findsOneWidget);
      expect(find.text('Avisos'), findsOneWidget);
    });
  });

  group(NotificationsView, () {
    late NotificationsCubit cubit;

    setUp(() {
      cubit = _MockNotificationsCubit();
      when(() => cubit.started()).thenAnswer((_) async {});
      when(() => cubit.turnOnTapped()).thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester,
      NotificationsStatus status, {
      Locale locale = rioplatense,
    }) {
      when(() => cubit.state).thenReturn(NotificationsState(status: status));
      return tester.pumpApp(
        BlocProvider.value(value: cubit, child: const NotificationsView()),
        locale: locale,
      );
    }

    Finder turnOn() => find.widgetWithText(FilledButton, 'Prender los avisos');

    const weekly = 'Uno por semana, el martes a las 19';

    testWidgets('shows progress while checking, saying what it does', (
      tester,
    ) async {
      await pump(tester, NotificationsStatus.checking);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text('Mirando si los avisos están prendidos…'),
        findsOneWidget,
      );
      expect(turnOn(), findsNothing);
    });

    testWidgets('reads out what it finds', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, NotificationsStatus.on);

      expect(
        tester.getSemantics(find.text('Los avisos están prendidos.')),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
    });

    group('swaps the check for what it found', () {
      Future<void> pumpFound(
        WidgetTester tester, {
        bool reduced = false,
      }) async {
        whenListen(
          cubit,
          Stream.value(
            const NotificationsState(status: NotificationsStatus.on),
          ),
          initialState: const NotificationsState(),
        );
        await tester.pumpApp(
          reducedMotion(
            reduced: reduced,
            child: BlocProvider.value(
              value: cubit,
              child: const NotificationsView(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      final found = find.text('Los avisos están prendidos.');
      final checking = find.text('Mirando si los avisos están prendidos…');

      testWidgets('settling it in', (tester) async {
        await pumpFound(tester);

        expect(checking, findsOneWidget);
        expect(
          find.ancestor(of: found, matching: find.byType(ScaleTransition)),
          findsWidgets,
        );
        await tester.pump(AppMotion.standardDuration);
        await tester.pump();
        expect(checking, findsNothing);
      });

      testWidgets('only cross-fading with reduced motion', (tester) async {
        await pumpFound(tester, reduced: true);

        expect(
          find.ancestor(of: found, matching: find.byType(ScaleTransition)),
          findsNothing,
        );
        await tester.pump(AppMotion.crossFade);
        await tester.pump();
        expect(checking, findsNothing);
      });
    });

    testWidgets('says they are on and what Ronda sends', (tester) async {
      await pump(tester, NotificationsStatus.on);

      expect(find.text('Los avisos están prendidos.'), findsOneWidget);
      expect(find.text(weekly), findsOneWidget);
      expect(find.text('Algún otro solo si cambia algo'), findsOneWidget);
      expect(turnOn(), findsNothing);
    });

    testWidgets('says they are off, with the button that asks', (tester) async {
      await pump(tester, NotificationsStatus.off);

      expect(find.text('Los avisos están apagados.'), findsOneWidget);
      expect(find.text(weekly), findsOneWidget);
      expect(
        find.bySemanticsIdentifier(NotificationsView.turnOnIdentifier),
        findsOneWidget,
      );

      await tester.tap(turnOn());
      verify(() => cubit.turnOnTapped()).called(1);
    });

    testWidgets('is felt on "Prender los avisos"', (tester) async {
      final haptics = recordHaptics(tester);
      await pump(tester, NotificationsStatus.off);

      await tester.tap(turnOn());

      expect(haptics, ['HapticFeedbackType.lightImpact']);
    });

    testWidgets('is not felt while the prompt is open', (tester) async {
      final haptics = recordHaptics(tester);
      await pump(tester, NotificationsStatus.asking);

      await tester.tap(turnOn());

      expect(haptics, isEmpty);
    });

    testWidgets('disables the button while the prompt is open', (tester) async {
      await pump(tester, NotificationsStatus.asking);

      expect(tester.widget<FilledButton>(turnOn()).onPressed, isNull);
    });

    testWidgets('points to the phone settings when still off after asking', (
      tester,
    ) async {
      await pump(tester, NotificationsStatus.refused);

      expect(find.text('Los avisos están apagados.'), findsOneWidget);
      expect(
        find.text(
          'Si el teléfono no te preguntó nada, prendelos en los ajustes del '
          'teléfono.',
        ),
        findsOneWidget,
      );
      expect(turnOn(), findsOneWidget);
    });

    testWidgets("says how to allow them in the phone's settings when "
        'blocked', (tester) async {
      await pump(tester, NotificationsStatus.blocked);

      expect(
        find.text(
          'Los avisos de Ronda están apagados en este teléfono. Si los '
          'querés, prendelos en los ajustes del teléfono.',
        ),
        findsOneWidget,
      );
      expect(find.text(weekly), findsNothing);
      expect(turnOn(), findsNothing);
    });

    testWidgets('says so when the permission cannot be read', (tester) async {
      await pump(tester, NotificationsStatus.unknown);

      expect(
        find.text(
          'No pudimos ver si los avisos están prendidos en este teléfono.',
        ),
        findsOneWidget,
      );
      expect(turnOn(), findsOneWidget);
    });

    testWidgets('in English', (tester) async {
      await pump(tester, NotificationsStatus.off, locale: const Locale('en'));

      expect(find.text('Notifications are off.'), findsOneWidget);
      expect(find.text('Turn on notifications'), findsOneWidget);
    });

    testWidgets('reads the permission again when the app comes back', (
      tester,
    ) async {
      await pump(tester, NotificationsStatus.blocked);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verify(() => cubit.started()).called(1);
    });
  });
}
