import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/phone_login/phone_login.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockPhoneLoginCubit extends MockCubit<PhoneLoginState>
    implements PhoneLoginCubit;

// Invented numbers, nobody's phone.
const _typed = '099 000 001';
final PhoneVerification _verification = PhoneVerification(
  phoneNumber: PhoneNumber.tryParse(_typed)!,
  sentAt: DateTime.utc(2026, 11, 2, 10),
  verificationId: 'verification-id',
);

const _typedState = PhoneLoginState(number: PhoneNumberInput.dirty(_typed));
final PhoneLoginState _onCode = _typedState.copyWith(
  step: PhoneLoginStep.code,
  verification: _verification,
);

Finder get _sendButton =>
    find.widgetWithText(FilledButton, 'Mandame el código');
Finder get _confirmButton => find.widgetWithText(FilledButton, 'Entrar');

void main() {
  group(PhoneLoginView, () {
    late PhoneLoginCubit cubit;

    setUp(() {
      cubit = _MockPhoneLoginCubit();
      when(() => cubit.state).thenReturn(const PhoneLoginState());
      when(() => cubit.sendCode()).thenAnswer((_) async {});
      when(() => cubit.resendCode()).thenAnswer((_) async {});
      when(() => cubit.confirmCode()).thenAnswer((_) async {});
    });

    Future<void> pumpSubject(
      WidgetTester tester, {
      Locale locale = rioplatense,
    }) => tester.pumpApp(
      BlocProvider.value(value: cubit, child: const PhoneLoginView()),
      locale: locale,
    );

    group('the number step', () {
      testWidgets('renders the copy with +598 filled in', (tester) async {
        await pumpSubject(tester);

        expect(find.text('Entrar con tu celular'), findsOneWidget);
        expect(find.text('¿Cuál es tu celular?'), findsOneWidget);
        expect(
          find.text(
            'Te mandamos un código por SMS para que entres. Tu número lo '
            'usamos solo para eso: nadie de tu ronda lo ve.',
          ),
          findsOneWidget,
        );
        expect(find.text('+598 '), findsOneWidget);
        expect(find.text('Con o sin el 0, como 09X XXX XXX'), findsOneWidget);
        expect(_sendButton, findsOneWidget);
      });

      testWidgets('asks for a phone keyboard and the number autofill', (
        tester,
      ) async {
        await pumpSubject(tester);

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.keyboardType, equals(TextInputType.phone));
        expect(field.autofillHints, equals([AutofillHints.telephoneNumber]));
      });

      testWidgets('reads in English', (tester) async {
        await pumpSubject(tester, locale: const Locale('en'));

        expect(find.text("What's your mobile number?"), findsOneWidget);
        expect(find.text('Text me the code'), findsOneWidget);
      });

      testWidgets('passes what is typed to numberChanged', (tester) async {
        await pumpSubject(tester);

        await tester.enterText(find.byType(TextField), _typed);

        verify(() => cubit.numberChanged(_typed)).called(1);
      });

      testWidgets('sends the code on the button and on the keyboard', (
        tester,
      ) async {
        await pumpSubject(tester);

        await tester.tap(_sendButton);
        await tester.showKeyboard(find.byType(TextField));
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pump();

        verify(() => cubit.sendCode()).called(2);
      });

      for (final (typed, message) in [
        ('+598 ', 'Escribí tu número de celular.'),
        (
          '2 000 0001',
          'Ese número es de un fijo. Escribí uno de celular, que empiece '
              'con 09.',
        ),
        ('12', 'Revisá el número: no parece de celular.'),
      ]) {
        testWidgets('says "$message" under the field for "$typed"', (
          tester,
        ) async {
          when(() => cubit.state).thenReturn(
            PhoneLoginState(
              number: PhoneNumberInput.dirty(typed),
              showInputError: true,
            ),
          );
          await pumpSubject(tester);

          expect(find.text(message), findsOneWidget);
        });
      }

      testWidgets('says nothing under a valid field', (tester) async {
        when(() => cubit.state)
            .thenReturn(_typedState.copyWith(showInputError: true));
        await pumpSubject(tester);

        expect(
          tester
              .widget<TextField>(find.byType(TextField))
              .decoration
              ?.errorText,
          isNull,
        );
      });

      testWidgets('shows that the code is on its way and takes no tap', (
        tester,
      ) async {
        when(() => cubit.state)
            .thenReturn(_typedState.copyWith(status: PhoneLoginStatus.sending));
        await pumpSubject(tester);

        expect(
          find.widgetWithText(FilledButton, 'Mandando el código…'),
          findsOneWidget,
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Mandando el código…'),
          warnIfMissed: false,
        );
        verifyNever(() => cubit.sendCode());
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
      });
    });

    group('errors', () {
      for (final (error, message, variant) in [
        (
          PhoneLoginError.invalidNumber,
          'Revisá el número: no parece de celular.',
          NoteBannerVariant.warning,
        ),
        (
          PhoneLoginError.tooManyRequests,
          'Pediste muchos códigos. Probá de nuevo en un rato, o entrá con '
              'Google.',
          NoteBannerVariant.warning,
        ),
        (
          PhoneLoginError.unavailable,
          'Ahora no podemos mandar SMS a ese número. Probá entrar con Google.',
          NoteBannerVariant.warning,
        ),
        (
          PhoneLoginError.network,
          'Sin conexión. Probá de nuevo cuando tengas señal.',
          NoteBannerVariant.offline,
        ),
        (
          PhoneLoginError.other,
          'No pudimos hacerte entrar. Probá de nuevo.',
          NoteBannerVariant.warning,
        ),
      ]) {
        testWidgets('says $error in a banner on the number', (tester) async {
          when(() => cubit.state)
              .thenReturn(_typedState.copyWith(error: () => error));
          await pumpSubject(tester);

          final banner = tester.widget<NoteBanner>(find.byType(NoteBanner));
          expect(banner.message, equals(message));
          expect(banner.variant, equals(variant));
        });
      }

      for (final (error, message) in [
        (
          PhoneLoginError.wrongCode,
          'Ese código no es. Revisá el SMS y probá de nuevo.',
        ),
        (PhoneLoginError.expiredCode, 'El código venció. Pedí otro.'),
      ]) {
        testWidgets('says $error in a banner on the code', (tester) async {
          when(() => cubit.state)
              .thenReturn(_onCode.copyWith(error: () => error));
          await pumpSubject(tester);

          expect(
            tester.widget<NoteBanner>(find.byType(NoteBanner)).message,
            equals(message),
          );
        });
      }
    });

    testWidgets('slides to the code step once the code is sent', (
      tester,
    ) async {
      final states = StreamController<PhoneLoginState>();
      addTearDown(states.close);
      whenListen(cubit, states.stream, initialState: _typedState);
      await pumpSubject(tester);

      states.add(_onCode);
      await tester.pumpAndSettle();

      expect(find.text('Escribí el código'), findsOneWidget);
      expect(find.text('¿Cuál es tu celular?'), findsNothing);
    });

    group('the code step', () {
      setUp(() => when(() => cubit.state).thenReturn(_onCode));

      testWidgets('says where the code went', (tester) async {
        await pumpSubject(tester);

        expect(find.text('Escribí el código'), findsOneWidget);
        expect(
          find.text('Te lo mandamos por SMS al +598 99 000 001.'),
          findsOneWidget,
        );
        expect(find.text('Te mandamos otro código.'), findsNothing);
        expect(_confirmButton, findsOneWidget);
      });

      testWidgets('asks for the one-time code autofill', (tester) async {
        await pumpSubject(tester);

        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.keyboardType, equals(TextInputType.number));
        expect(field.autofillHints, equals([AutofillHints.oneTimeCode]));
      });

      testWidgets('says so after a resend', (tester) async {
        when(() => cubit.state).thenReturn(_onCode.copyWith(resent: true));
        await pumpSubject(tester);

        expect(find.text('Te mandamos otro código.'), findsOneWidget);
      });

      testWidgets('passes the code on and confirms it', (tester) async {
        await pumpSubject(tester);

        await tester.enterText(find.byType(TextField), '123456');
        await tester.tap(_confirmButton);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        verify(() => cubit.codeChanged('123456')).called(1);
        verify(() => cubit.confirmCode()).called(2);
      });

      testWidgets('says the code has six digits', (tester) async {
        when(() => cubit.state).thenReturn(
          _onCode.copyWith(
            code: const SmsCode.dirty('12'),
            showInputError: true,
          ),
        );
        await pumpSubject(tester);

        expect(find.text('El código tiene 6 números.'), findsOneWidget);
      });

      testWidgets('counts down to the resend, which takes no tap', (
        tester,
      ) async {
        when(() => cubit.state)
            .thenReturn(_onCode.copyWith(secondsToResend: 27));
        await pumpSubject(tester);

        final resend = find.widgetWithText(
          TextButton,
          'Podés pedir otro en 27 s',
        );
        expect(resend, findsOneWidget);
        expect(tester.widget<TextButton>(resend).onPressed, isNull);
      });

      testWidgets('resends once the wait is over', (tester) async {
        await pumpSubject(tester);

        await tester.tap(
          find.widgetWithText(TextButton, 'Mandame otro código'),
        );

        verify(() => cubit.resendCode()).called(1);
      });

      testWidgets('shows that the resend is on its way', (tester) async {
        when(() => cubit.state)
            .thenReturn(_onCode.copyWith(status: PhoneLoginStatus.sending));
        await pumpSubject(tester);

        expect(
          find.widgetWithText(TextButton, 'Mandando el código…'),
          findsOneWidget,
        );
      });

      testWidgets('says when no more codes may be sent', (tester) async {
        when(() => cubit.state).thenReturn(
          _onCode.copyWith(
            verification: PhoneVerification(
              phoneNumber: _verification.phoneNumber,
              sentAt: _verification.sentAt,
              sends: 4,
            ),
          ),
        );
        await pumpSubject(tester);

        expect(
          find.text(
            'Ya te mandamos varios códigos. Si no te llega ninguno, volvé y '
            'entrá con Google.',
          ),
          findsOneWidget,
        );
        expect(find.text('Mandame otro código'), findsNothing);
      });

      testWidgets('goes back to the number on "Cambiar el número"', (
        tester,
      ) async {
        await pumpSubject(tester);

        await tester.tap(find.text('Cambiar el número'));

        verify(() => cubit.changeNumber()).called(1);
      });

      for (final status in [
        PhoneLoginStatus.confirming,
        PhoneLoginStatus.success,
      ]) {
        testWidgets('shows it is signing in and takes no tap while '
            '${status.name}', (tester) async {
          when(() => cubit.state).thenReturn(_onCode.copyWith(status: status));
          await pumpSubject(tester);

          expect(
            find.widgetWithText(FilledButton, 'Entrando…'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<TextButton>(
                  find.widgetWithText(TextButton, 'Cambiar el número'),
                )
                .onPressed,
            isNull,
          );
        });
      }

      testWidgets('empties the field when a new code arrives', (tester) async {
        final states = StreamController<PhoneLoginState>();
        addTearDown(states.close);
        whenListen(cubit, states.stream, initialState: _onCode);
        await pumpSubject(tester);
        await tester.enterText(find.byType(TextField), '999');

        states.add(
          _onCode.copyWith(
            verification: PhoneVerification(
              phoneNumber: _verification.phoneNumber,
              sentAt: _verification.sentAt,
              sends: 2,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('999'), findsNothing);
      });
    });
  });
}
