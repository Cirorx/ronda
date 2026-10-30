import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/login/login.dart';

import '../../helpers/helpers.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

void main() {
  group(LoginPage, () {
    late AuthRepository authRepository;

    setUp(() {
      authRepository = _MockAuthRepository();
    });

    group('renders', () {
      testWidgets('$LoginView with a $LoginCubit', (tester) async {
        await tester.pumpApp(
          RepositoryProvider.value(
            value: authRepository,
            child: const LoginPage(),
          ),
        );

        expect(find.byType(LoginView), findsOneWidget);
        final context = tester.element(find.byType(LoginView));
        expect(context.read<LoginCubit>().state, equals(const LoginState()));
        expect(
          tester.widget<LoginView>(find.byType(LoginView)).reason,
          equals(LoginReason.signIn),
        );
      });

      testWidgets('$LoginView with the reason it was given', (tester) async {
        await tester.pumpApp(
          RepositoryProvider.value(
            value: authRepository,
            child: const LoginPage(reason: LoginReason.keepSeat),
          ),
        );

        expect(
          tester.widget<LoginView>(find.byType(LoginView)).reason,
          equals(LoginReason.keepSeat),
        );
      });
    });
  });
}
