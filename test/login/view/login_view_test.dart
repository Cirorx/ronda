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

    Future<void> pumpSubject(WidgetTester tester) => tester.pumpApp(
      BlocProvider.value(value: cubit, child: const LoginView()),
    );

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
