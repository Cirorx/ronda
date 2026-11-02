import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:contact_repository/contact_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/settings/cubit/report_cubit.dart';
import 'package:ronda/settings/models/report_text.dart';
import 'package:ronda/settings/settings.dart';
import 'package:ronda/settings/widgets/helpline_block.dart';
import 'package:ronda/settings/widgets/report_receipt_card.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:safety_repository/safety_repository.dart';

import '../../helpers/helpers.dart';

class _MockContactRepository extends Mock implements ContactRepository;

class _MockSafetyRepository extends Mock implements SafetyRepository;

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockContactCubit extends MockCubit<ContactState> implements ContactCubit;

class _MockReportCubit extends MockCubit<ReportState> implements ReportCubit;

const _email = 'hola@example.com';
final _at = DateTime.utc(2026, 11, 2, 15);

const _people = [
  ReportPerson(uid: 'beto', firstName: 'Beto'),
  ReportPerson(uid: 'cora', firstName: 'Cora'),
];

/// The screen's list.
final Finder _list = find.byType(Scrollable).first;

void main() {
  setUpAll(() => registerFallbackValue(ReportTag.other));

  group(ReportPage, () {
    testWidgets("provides the report's cubit and the helplines' cubit", (
      tester,
    ) async {
      final contacts = _MockContactRepository();
      final safety = _MockSafetyRepository();
      final appBloc = _MockAppBloc();
      when(() => contacts.email).thenReturn(_email);
      when(() => appBloc.state).thenReturn(
        const AppState(
          status: AppStatus.authenticated,
          user: User(id: 'ana'),
        ),
      );
      when(() => safety.watchReceipts('ana'))
          .thenAnswer((_) => Stream.value(const []));
      when(safety.reportPeople).thenAnswer((_) async => _people);

      await tester.pumpApp(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ContactRepository>.value(value: contacts),
            RepositoryProvider<SafetyRepository>.value(value: safety),
          ],
          child: BlocProvider<AppBloc>.value(
            value: appBloc,
            child: const ReportPage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ReportView), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);
      expect(find.text('Alguien de afuera'), findsOneWidget);
    });
  });

  group(ReportView, () {
    late ContactCubit contact;
    late ReportCubit cubit;

    setUp(() {
      contact = _MockContactCubit();
      when(() => contact.state).thenReturn(const ContactState(email: _email));
      when(() => contact.helplineTapped(any())).thenAnswer((_) async {});
      cubit = _MockReportCubit();
      when(() => cubit.state).thenReturn(
        const ReportState(status: ReportStatus.ready, people: _people),
      );
      when(cubit.submitted).thenAnswer((_) async {});
      when(() => cubit.addedTo(any())).thenAnswer((_) async {});
      when(() => cubit.withdrawn(any())).thenAnswer((_) async {});
    });

    setUpAll(() => registerFallbackValue(Helpline.emergencies));

    Future<void> pump(WidgetTester tester, {Locale locale = rioplatense}) =>
        tester.pumpApp(
          MultiBlocProvider(
            providers: [
              BlocProvider<ContactCubit>.value(value: contact),
              BlocProvider<ReportCubit>.value(value: cubit),
            ],
            child: const ReportView(),
          ),
          locale: locale,
          // Tall enough that the list builds the whole screen.
          size: const Size(360, 2400),
        );

    group('renders', () {
      testWidgets('who reads it, the danger line, the form and helplines', (
        tester,
      ) async {
        await pump(tester);

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Contar algo que pasó'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Contá qué pasó. Lo lee una persona, no un programa. La otra '
            'persona no se entera de que contaste.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Si estás en peligro ahora, llamá al 911.'),
          findsOneWidget,
        );
        expect(find.text('¿Qué pasó?'), findsOneWidget);
        for (final tag in [
          'Me pidió plata',
          'Me molestó',
          'Insistió con algo romántico',
          'Había un menor',
          'Quiso ir a un lugar privado',
          'Otra cosa',
        ]) {
          expect(find.text(tag), findsOneWidget);
        }
        expect(find.text('¿Con quién?'), findsOneWidget);
        expect(find.text('Cora'), findsOneWidget);
        expect(find.text('Escribir un mail'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('911'),
          100,
          scrollable: _list,
        );
        expect(
          find.text('¿Necesitás hablar con alguien ahora?'),
          findsOneWidget,
        );
      });

      testWidgets('in English', (tester) async {
        await pump(tester, locale: const Locale('en'));

        expect(
          find.text("If you're in danger right now, call 911."),
          findsOneWidget,
        );
        expect(find.text('Someone from outside'), findsOneWidget);
        expect(find.text('Asked me for money'), findsOneWidget);
      });

      testWidgets('a ring while it reads', (tester) async {
        when(() => cubit.state).thenReturn(const ReportState());

        await pump(tester);

        expect(find.text('Cargando…'), findsOneWidget);
        expect(find.text('¿Qué pasó?'), findsNothing);
      });

      testWidgets('what Mandar still needs, and Mandar off', (tester) async {
        await pump(tester);

        expect(
          find.text('Elegí con quién fue, y una etiqueta o unas palabras.'),
          findsOneWidget,
        );
        final send = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Mandar'),
        );
        expect(send.onPressed, isNull);
      });

      testWidgets('words over the limit', (tester) async {
        when(() => cubit.state).thenReturn(
          ReportState(
            status: ReportStatus.ready,
            text: ReportText.dirty('x' * (ReportText.maxLength + 1)),
          ),
        );

        await pump(tester);

        expect(find.text('Es muy largo: hasta 2000 letras.'), findsOneWidget);
      });

      for (final (status, line) in [
        (ReportSendStatus.failed, 'No se mandó. Probá de nuevo.'),
        (
          ReportSendStatus.tooMany,
          'Por hoy ya mandaste varios. Si es urgente, llamá al 911.',
        ),
      ]) {
        testWidgets('says so when sending ends $status', (tester) async {
          when(() => cubit.state).thenReturn(
            ReportState(
              status: ReportStatus.ready,
              aboutUid: '',
              tags: const {ReportTag.other},
              send: status,
            ),
          );

          await pump(tester);

          expect(find.text(line), findsOneWidget);
        });
      }

      testWidgets('a ring in Mandar while it goes', (tester) async {
        when(() => cubit.state).thenReturn(
          const ReportState(
            status: ReportStatus.ready,
            aboutUid: '',
            tags: {ReportTag.other},
            send: ReportSendStatus.sending,
          ),
        );

        await pump(tester);

        expect(find.text('Mandando…'), findsOneWidget);
      });
    });

    group('the form', () {
      testWidgets('picks tags, who and words', (tester) async {
        await pump(tester);

        await tester.tap(
          find.bySemanticsIdentifier('${ReportView.tagIdentifier}.bothered'),
        );
        await tester.tap(
          find.bySemanticsIdentifier('${ReportView.whoIdentifier}.beto'),
        );
        await tester.tap(
          find.bySemanticsIdentifier('${ReportView.whoIdentifier}.outside'),
        );
        await tester.enterText(find.byType(TextField), 'Me insistió');

        verify(() => cubit.tagToggled(ReportTag.bothered)).called(1);
        verify(() => cubit.aboutChosen('beto')).called(1);
        verify(() => cubit.aboutChosen('')).called(1);
        verify(() => cubit.textChanged('Me insistió')).called(1);
      });

      testWidgets('Mandar sends, and the field empties once saved', (
        tester,
      ) async {
        const ready = ReportState(
          status: ReportStatus.ready,
          aboutUid: 'beto',
          tags: {ReportTag.bothered},
        );
        final states = StreamController<ReportState>();
        addTearDown(states.close);
        whenListen(cubit, states.stream, initialState: ready);
        await pump(tester);
        await tester.enterText(find.byType(TextField), 'Me insistió');
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Mandar'));

        await tester.tap(find.widgetWithText(FilledButton, 'Mandar'));
        verify(cubit.submitted).called(1);
        expect(find.text('Me insistió'), findsOneWidget);
        states
          ..add(ready.copyWith(send: ReportSendStatus.sending))
          ..add(
            const ReportState(
              status: ReportStatus.ready,
              send: ReportSendStatus.sent,
            ),
          );
        await tester.pump();
        await tester.pump();

        expect(find.text('Me insistió'), findsNothing);
      });
    });

    group('a receipt', () {
      final receipt = ReportReceipt(id: 'rep1', createdAt: _at);

      setUp(() {
        when(() => cubit.state).thenReturn(
          ReportState(
            status: ReportStatus.ready,
            receipts: [
              receipt,
              ReportReceipt(id: 'gone', createdAt: _at, withdrawn: true),
            ],
          ),
        );
      });

      testWidgets('says it arrived, only for the open ones', (tester) async {
        await pump(tester);

        expect(find.byType(ReportReceiptCard), findsOneWidget);
        expect(find.text('Lo recibimos. Lo lee una persona.'), findsOneWidget);
        expect(find.textContaining('Lo contaste el'), findsOneWidget);
      });

      testWidgets('Agregar algo sends the words from the sheet', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          ReportState(
            status: ReportStatus.ready,
            receipts: [receipt],
            addition: const ReportText.dirty('Y el jueves'),
          ),
        );
        await pump(tester);

        await tester.tap(
          find.bySemanticsIdentifier('${ReportReceiptCard.addIdentifier}.rep1'),
        );
        await tester.pumpAndSettle();
        expect(find.text('¿Qué querés agregar?'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, 'Y el jueves');
        await tester.tap(
          find.bySemanticsIdentifier(
            '${ReportReceiptCard.addSheetIdentifier}.primary',
          ),
        );
        await tester.pumpAndSettle();

        verify(() => cubit.additionChanged('Y el jueves')).called(1);
        verify(() => cubit.addedTo('rep1')).called(1);
        expect(find.text('¿Qué querés agregar?'), findsNothing);
      });

      testWidgets('Agregar does nothing without words, and says too long', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          ReportState(
            status: ReportStatus.ready,
            receipts: [receipt],
            addition: ReportText.dirty('x' * (ReportText.maxLength + 1)),
          ),
        );
        await pump(tester);
        await tester.tap(
          find.bySemanticsIdentifier('${ReportReceiptCard.addIdentifier}.rep1'),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.bySemanticsIdentifier(
            '${ReportReceiptCard.addSheetIdentifier}.primary',
          ),
        );
        await tester.pumpAndSettle();

        verifyNever(() => cubit.addedTo(any()));
        expect(find.text('Es muy largo: hasta 2000 letras.'), findsOneWidget);
      });

      testWidgets('Retirar asks first, and Mejor no keeps it', (tester) async {
        await pump(tester);
        final withdraw = find.bySemanticsIdentifier(
          '${ReportReceiptCard.withdrawIdentifier}.rep1',
        );

        await tester.tap(withdraw);
        await tester.pumpAndSettle();
        expect(find.text('¿Retirás lo que contaste?'), findsOneWidget);
        await tester.tap(
          find.bySemanticsIdentifier(
            '${ReportReceiptCard.withdrawSheetIdentifier}.secondary',
          ),
        );
        await tester.pumpAndSettle();
        verifyNever(() => cubit.withdrawn(any()));

        await tester.tap(withdraw);
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsIdentifier(
            '${ReportReceiptCard.withdrawSheetIdentifier}.primary',
          ),
        );
        await tester.pumpAndSettle();
        verify(() => cubit.withdrawn('rep1')).called(1);
      });

      for (final (action, line) in [
        (ReceiptAction.added, 'Lo agregamos. Lo lee una persona.'),
        (ReceiptAction.failed, 'No se pudo. Probá de nuevo.'),
      ]) {
        testWidgets('says when $action', (tester) async {
          when(() => cubit.state).thenReturn(
            ReportState(
              status: ReportStatus.ready,
              receipts: [receipt],
              receiptId: 'rep1',
              receiptAction: action,
            ),
          );

          await pump(tester);

          expect(find.text(line), findsOneWidget);
        });
      }

      testWidgets('its buttons wait while it is busy', (tester) async {
        when(() => cubit.state).thenReturn(
          ReportState(
            status: ReportStatus.ready,
            receipts: [receipt],
            receiptId: 'rep1',
            receiptAction: ReceiptAction.withdrawing,
          ),
        );

        await pump(tester);

        final buttons = tester.widgetList<OutlinedButton>(
          find.descendant(
            of: find.byType(ReportReceiptCard),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(buttons.every((b) => b.onPressed == null), isTrue);
      });
    });

    group('the helplines', () {
      testWidgets('each number as a button that says what it calls', (
        tester,
      ) async {
        await pump(tester);

        for (final helpline in Helpline.values) {
          expect(
            find.bySemanticsIdentifier(HelplineBlock.identifier(helpline)),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel('Llamar al ${helpline.number}'),
            findsOneWidget,
          );
        }
      });

      for (final helpline in Helpline.values) {
        testWidgets('calls ${helpline.number} from its button', (tester) async {
          await pump(tester);
          final number = find.widgetWithText(OutlinedButton, helpline.number);
          await tester.ensureVisible(number);
          await tester.pumpAndSettle();

          await tester.tap(number);

          verify(() => contact.helplineTapped(helpline)).called(1);
        });

        testWidgets('calls ${helpline.number} from its semantics action', (
          tester,
        ) async {
          await pump(tester);
          final semantics = tester.ensureSemantics();

          tester.semantics.tap(
            find.semantics.byPredicate(
              (node) => node.identifier == HelplineBlock.identifier(helpline),
            ),
          );

          verify(() => contact.helplineTapped(helpline)).called(1);
          semantics.dispose();
        });
      }

      testWidgets('says so in the helplines when no dialer opens', (
        tester,
      ) async {
        whenListen(
          contact,
          Stream.value(
            const ContactState(
              email: _email,
              status: ContactStatus.callFailed,
              helpline: Helpline.suicidePreventionMobile,
            ),
          ),
          initialState: const ContactState(email: _email),
        );
        await pump(tester);
        await tester.pump();
        await tester.pump(AppMotion.standardDuration);
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(HelplineBlock),
            matching: find.text('No se abrió el teléfono. Marcá el *0767.'),
          ),
          findsOneWidget,
        );
      });
    });
  });
}
