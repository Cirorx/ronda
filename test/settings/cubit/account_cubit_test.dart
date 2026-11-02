import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/settings/settings.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

void main() {
  group(AccountCubit, () {
    late AuthRepository authRepository;

    setUp(() => authRepository = _MockAuthRepository());

    test('starts with the $SignInAccount the repository reads', () {
      const account = SignInAccount(
        method: SignInMethod.phone,
        address: '+59899123456',
      );
      when(() => authRepository.signInAccount).thenReturn(account);

      expect(
        AccountCubit(authRepository: authRepository).state,
        equals(account),
      );
    });

    test('starts with null when nobody is signed in', () {
      when(() => authRepository.signInAccount).thenReturn(null);

      expect(AccountCubit(authRepository: authRepository).state, isNull);
    });
  });
}
