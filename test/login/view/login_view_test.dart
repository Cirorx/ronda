import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/login/login.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockLoginCubit extends MockCubit<LoginState> implements LoginCubit;

Finder get _googleButton =>
    find.widgetWithText(FilledButton, 'Seguir con Google');

void main() {
  group(LoginView, () {
    late LoginCubit cubit;

    setUp(() {
      cubit = _MockLoginCubit();
      when(() => cubit.state).thenReturn(const LoginState());
      when(() => cubit.signInWithGoogle()).thenAnswer((_) async {});
    });

    final opened = <Uri>[];

    Future<void> pumpSubject(
      WidgetTester tester, {
      LoginReason reason = LoginReason.signIn,
      Locale locale = rioplatense,
    }) {
      opened.clear();
      return tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: LoginView(
            reason: reason,
            openLink: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
        locale: locale,
      );
    }

    group('says why sign-in comes now', () {
      testWidgets('after the payoff: "Guardá tu lugar"', (tester) async {
        await pumpSubject(tester, reason: LoginReason.keepSeat);

        expect(find.text('Guardá tu lugar'), findsOneWidget);
        expect(
          find.text(
            'Para guardarte el lugar y avisarte el día de la ronda, entrá con '
            'tu cuenta.',
          ),
          findsOneWidget,
        );
        expect(find.text('Primero, entrá con tu cuenta'), findsNothing);
        expect(find.text('No publicamos nada en tu cuenta'), findsOneWidget);
      });

      testWidgets('after the voice door: to listen', (tester) async {
        await pumpSubject(tester, reason: LoginReason.voice);

        expect(
          find.text('Para escucharte necesitamos que entres con tu cuenta'),
          findsOneWidget,
        );
        expect(find.text('No publicamos nada en tu cuenta'), findsOneWidget);
      });

      testWidgets('in English', (tester) async {
        await pumpSubject(
          tester,
          reason: LoginReason.keepSeat,
          locale: const Locale('en'),
        );

        expect(find.text('Keep your place'), findsOneWidget);
        expect(
          find.text(
            'To keep your place and let you know the day of the ronda, sign '
            'in with your account.',
          ),
          findsOneWidget,
        );
      });
    });

    group('links to make a Google account', () {
      testWidgets("opening Google's page when tapped", (tester) async {
        await pumpSubject(tester);

        await tester.tap(
          find.text(
            '¿No tenés cuenta de Google? Te ayudamos a crear una en un minuto.',
          ),
        );

        expect(
          opened,
          equals([Uri.parse('https://accounts.google.com/signup')]),
        );
      });

      testWidgets('read as a link, with a 48 dp target', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpSubject(tester);

        final link = find.bySemanticsIdentifier(
          LoginView.createAccountIdentifier,
        );
        expect(
          tester.getSemantics(link),
          isSemantics(
            label:
                '¿No tenés cuenta de Google? Te ayudamos a crear una en un '
                'minuto.',
            isLink: true,
            hasTapAction: true,
          ),
        );
        expect(tester.getSize(link).height, greaterThanOrEqualTo(48));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

        tester.semantics.tap(
          find.semantics.byLabel(RegExp('^¿No tenés cuenta de Google')),
        );
        expect(opened, equals([LoginView.createAccountUrl]));
        handle.dispose();
      });

      test('in the browser by default', () {
        expect(const LoginView().openLink, equals(openInBrowser));
      });
    });

    group('renders', () {
      testWidgets('the sign-in copy from PRODUCT.md in es-419', (tester) async {
        await pumpSubject(tester);

        expect(find.text('Primero, entrá con tu cuenta'), findsOneWidget);
        expect(find.text('No publicamos nada en tu cuenta'), findsOneWidget);
        expect(
          find.text('No vemos tus contactos, tus fotos ni tus mails'),
          findsOneWidget,
        );
        expect(
          find.text('En Ronda te conocen solo por tu nombre de pila'),
          findsOneWidget,
        );
        expect(_googleButton, findsOneWidget);
        expect(
          find.text(
            '¿No tenés cuenta de Google? Te ayudamos a crear una en un minuto.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('a Google button Maestro finds by its identifier', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpSubject(tester);

        expect(
          find.bySemanticsIdentifier(LoginView.googleButtonIdentifier),
          findsOneWidget,
        );
        expect(
          tester.getSemantics(
            find.bySemanticsIdentifier(LoginView.googleButtonIdentifier),
          ),
          isSemantics(
            label: 'Seguir con Google',
            isButton: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      });

      testWidgets('no error before a failed sign-in', (tester) async {
        await pumpSubject(tester);

        expect(find.byType(NoteBanner), findsNothing);
      });

      testWidgets('the connection error after a network failure', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          const LoginState(
            status: LoginStatus.failure,
            error: LoginError.network,
          ),
        );

        await pumpSubject(tester);

        expect(
          find.text('Sin conexión. Probá de nuevo cuando tengas señal.'),
          findsOneWidget,
        );
      });

      testWidgets('the generic error after any other failure', (tester) async {
        when(() => cubit.state).thenReturn(
          const LoginState(
            status: LoginStatus.failure,
            error: LoginError.other,
          ),
        );

        await pumpSubject(tester);

        expect(
          find.text('No pudimos hacerte entrar. Probá de nuevo.'),
          findsOneWidget,
        );
      });
    });

    group('calls', () {
      testWidgets('signInWithGoogle when the Google button is tapped', (
        tester,
      ) async {
        await pumpSubject(tester);

        await tester.tap(_googleButton);
        await tester.pump();

        verify(() => cubit.signInWithGoogle()).called(1);
      });

      for (final status in [LoginStatus.inProgress, LoginStatus.success]) {
        testWidgets('nothing on a tap while ${status.name}', (tester) async {
          when(() => cubit.state).thenReturn(LoginState(status: status));
          await pumpSubject(tester);

          await tester.tap(_googleButton);
          await tester.pump();

          verifyNever(() => cubit.signInWithGoogle());
        });
      }
    });
  });
}
