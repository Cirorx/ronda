import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/settings/settings.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockAccountCubit extends MockCubit<SignInAccount?>
    implements AccountCubit;

void main() {
  group(AccountTile, () {
    late AccountCubit cubit;

    setUp(() => cubit = _MockAccountCubit());

    Future<void> pump(
      WidgetTester tester,
      SignInAccount? account, {
      Locale locale = rioplatense,
    }) {
      when(() => cubit.state).thenReturn(account);
      return tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: AccountTile()),
        ),
        locale: locale,
      );
    }

    group('renders', () {
      testWidgets('Google and the email', (tester) async {
        await pump(
          tester,
          const SignInAccount(
            method: SignInMethod.google,
            address: 'vecina@example.com',
          ),
        );

        expect(find.text('Entraste con Google'), findsOneWidget);
        expect(find.text('vecina@example.com'), findsOneWidget);
        expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
      });

      testWidgets('the phone and the number, spaced', (tester) async {
        await pump(
          tester,
          const SignInAccount(
            method: SignInMethod.phone,
            address: '+59899123456',
          ),
        );

        expect(find.text('Entraste con tu celular'), findsOneWidget);
        expect(find.text('+598 99 123 456'), findsOneWidget);
        expect(find.byIcon(Icons.smartphone), findsOneWidget);
      });

      testWidgets('in English', (tester) async {
        await pump(
          tester,
          const SignInAccount(method: SignInMethod.phone),
          locale: const Locale('en'),
        );

        expect(
          find.text('You signed in with your mobile number'),
          findsOneWidget,
        );
      });

      testWidgets('only the way in when there is no address', (tester) async {
        await pump(tester, const SignInAccount(method: SignInMethod.google));

        final tile = tester.widget<ListTile>(find.byType(ListTile));
        expect(tile.subtitle, isNull);
      });

      testWidgets('nothing when the way in is unknown', (tester) async {
        await pump(tester, null);

        expect(find.byType(ListTile), findsNothing);
      });

      testWidgets('one semantics node, nothing to tap', (tester) async {
        await pump(
          tester,
          const SignInAccount(
            method: SignInMethod.google,
            address: 'vecina@example.com',
          ),
        );

        expect(find.bySemanticsIdentifier(AccountTile.identifier), findsOne);
        expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
      });
    });
  });
}
