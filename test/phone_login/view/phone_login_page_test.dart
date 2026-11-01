import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/phone_login/phone_login.dart';

import '../../helpers/helpers.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

void main() {
  group(PhoneLoginPage, () {
    testWidgets('renders $PhoneLoginView with a $PhoneLoginCubit', (
      tester,
    ) async {
      await tester.pumpApp(
        RepositoryProvider<AuthRepository>.value(
          value: _MockAuthRepository(),
          child: const PhoneLoginPage(),
        ),
      );

      expect(find.byType(PhoneLoginView), findsOneWidget);
      final context = tester.element(find.byType(PhoneLoginView));
      expect(
        context.read<PhoneLoginCubit>().state,
        equals(const PhoneLoginState()),
      );
      expect(PhoneLoginPage.segment, equals('celular'));
    });
  });
}
