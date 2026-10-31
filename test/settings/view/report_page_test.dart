import 'package:bloc_test/bloc_test.dart';
import 'package:contact_repository/contact_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/settings/settings.dart';
import 'package:ronda/settings/widgets/helpline_block.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockContactRepository extends Mock implements ContactRepository;

class _MockContactCubit extends MockCubit<ContactState> implements ContactCubit;

const _email = 'hola@example.com';

/// The screen's list, not the selectable text's own scrollable.
final Finder _list = find.byType(Scrollable).first;

void main() {
  group(ReportPage, () {
    testWidgets('provides a $ContactCubit over the repository', (tester) async {
      final repository = _MockContactRepository();
      when(() => repository.email).thenReturn(_email);

      await tester.pumpApp(
        RepositoryProvider<ContactRepository>.value(
          value: repository,
          child: const ReportPage(),
        ),
      );

      expect(find.byType(ReportView), findsOneWidget);
      expect(find.text('Escribinos a $_email.'), findsOneWidget);
    });
  });

  group(ReportView, () {
    late ContactCubit cubit;

    setUp(() {
      cubit = _MockContactCubit();
      when(() => cubit.state).thenReturn(const ContactState(email: _email));
      when(
        () => cubit.emailTapped(
          subject: any(named: 'subject'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {});
      when(() => cubit.helplineTapped(any())).thenAnswer((_) async {});
    });

    setUpAll(() => registerFallbackValue(Helpline.emergencies));

    Future<void> pump(WidgetTester tester, {Locale locale = rioplatense}) =>
        tester.pumpApp(
          BlocProvider.value(value: cubit, child: const ReportView()),
          locale: locale,
        );

    group('renders', () {
      testWidgets('who reads it, the address and the helplines', (
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
        expect(find.text('Escribinos a $_email.'), findsOneWidget);
        expect(find.text('Escribir un mail'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('911'),
          100,
          scrollable: _list,
        );
        expect(
          find.text('¿Necesitás hablar con alguien ahora?'),
          findsOneWidget,
        );
        expect(find.text('Línea de Prevención del Suicidio'), findsOneWidget);
        expect(find.text('0800 0767'), findsOneWidget);
        expect(find.text('*0767'), findsOneWidget);
        expect(find.text('Emergencias'), findsOneWidget);
      });

      testWidgets('in English', (tester) async {
        await pump(tester, locale: const Locale('en'));

        expect(find.text('Tell us something that happened'), findsOneWidget);
        expect(find.text('Write to us at $_email.'), findsOneWidget);
        expect(
          find.text('Do you need to talk to someone now?'),
          findsOneWidget,
        );
      });

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
    });

    testWidgets('writes a mail with the report subject', (tester) async {
      await pump(tester);

      await tester.tap(find.bySemanticsIdentifier(ReportView.emailIdentifier));

      verify(() => cubit.emailTapped(subject: 'Ronda: algo que pasó'))
          .called(1);
    });

    for (final helpline in Helpline.values) {
      testWidgets('calls ${helpline.number} from its button', (tester) async {
        await pump(tester);
        final number = find.widgetWithText(OutlinedButton, helpline.number);
        await tester.ensureVisible(number);
        await tester.pumpAndSettle();

        await tester.tap(number);

        verify(() => cubit.helplineTapped(helpline)).called(1);
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

        verify(() => cubit.helplineTapped(helpline)).called(1);
        semantics.dispose();
      });
    }

    group('says so in a banner, read out, where it happened', () {
      Future<void> pumpFailed(WidgetTester tester, ContactState failed) async {
        whenListen(
          cubit,
          Stream.value(failed),
          initialState: const ContactState(email: _email),
        );
        await pump(tester);
        await tester.pump();
        await tester.pump(AppMotion.standardDuration);
        await tester.pump();
      }

      testWidgets('when no mail app opens, under the mail button', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpFailed(
          tester,
          const ContactState(email: _email, status: ContactStatus.emailFailed),
        );

        final note = find.text('No se abrió el correo. Escribinos a $_email.');
        expect(
          find.descendant(of: find.byType(NoteBanner), matching: note),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.getSemantics(note), isSemantics(isLiveRegion: true));
        expect(
          find.descendant(of: find.byType(HelplineBlock), matching: note),
          findsNothing,
        );
        semantics.dispose();
      });

      testWidgets('when no dialer opens, in the helplines', (tester) async {
        await pumpFailed(
          tester,
          const ContactState(
            email: _email,
            status: ContactStatus.callFailed,
            helpline: Helpline.suicidePreventionMobile,
          ),
        );

        expect(
          find.descendant(
            of: find.byType(HelplineBlock),
            matching: find.text('No se abrió el teléfono. Marcá el *0767.'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('settling it in as it arrives', (tester) async {
        whenListen(
          cubit,
          Stream.value(
            const ContactState(
              email: _email,
              status: ContactStatus.emailFailed,
            ),
          ),
          initialState: const ContactState(email: _email),
        );
        await pump(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.ancestor(
            of: find.byType(NoteBanner),
            matching: find.byType(ScaleTransition),
          ),
          findsWidgets,
        );
      });

      testWidgets('nothing before anything failed', (tester) async {
        await pump(tester);

        expect(find.byType(NoteBanner), findsNothing);
      });
    });
  });
}
