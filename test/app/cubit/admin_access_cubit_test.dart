import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app/cubit/admin_access_cubit.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

const _owner = User(id: 'demo-owner');
const _member = User(id: 'demo-member');

void main() {
  group(AdminAccessCubit, () {
    late AuthRepository authRepository;
    late StreamController<User> tokens;

    setUp(() {
      authRepository = _MockAuthRepository();
      tokens = StreamController<User>.broadcast();
      addTearDown(tokens.close);
      when(() => authRepository.tokenChanges).thenAnswer((_) => tokens.stream);
      when(
        () => authRepository.hasAdminClaim(
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer((_) async => false);
    });

    AdminAccessCubit build() =>
        AdminAccessCubit(authRepository: authRepository);

    test('starts as ${AdminAccess.signedOut}', () {
      expect(build().state, AdminAccess.signedOut);
    });

    group('subscribe', () {
      blocTest<AdminAccessCubit, AdminAccess>(
        'emits [checking, admin] when the fresh token carries the claim',
        setUp: () =>
            when(() => authRepository.hasAdminClaim(forceRefresh: true))
                .thenAnswer((_) async => true),
        build: build,
        act: (cubit) {
          cubit.subscribe();
          tokens.add(_owner);
        },
        expect: () => [AdminAccess.checking, AdminAccess.admin],
        verify: (_) =>
            verify(() => authRepository.hasAdminClaim(forceRefresh: true))
                .called(1),
      );

      blocTest<AdminAccessCubit, AdminAccess>(
        'emits [checking, member] for a token without the claim',
        build: build,
        act: (cubit) {
          cubit.subscribe();
          tokens.add(_member);
        },
        expect: () => [AdminAccess.checking, AdminAccess.member],
      );

      blocTest<AdminAccessCubit, AdminAccess>(
        'forces a fresh token once per sign-in and reads renewals as they '
        'come, so a lost claim shows at the next renewal',
        setUp: () {
          when(() => authRepository.hasAdminClaim(forceRefresh: true))
              .thenAnswer((_) async => true);
          when(() => authRepository.hasAdminClaim(forceRefresh: false))
              .thenAnswer((_) async => false);
        },
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          tokens.add(_owner);
          await Future<void>.delayed(Duration.zero);
          tokens.add(_owner);
        },
        expect: () => [
          AdminAccess.checking,
          AdminAccess.admin,
          AdminAccess.member,
        ],
        verify: (_) {
          verify(() => authRepository.hasAdminClaim(forceRefresh: true))
              .called(1);
          verify(() => authRepository.hasAdminClaim(forceRefresh: false))
              .called(1);
        },
      );

      blocTest<AdminAccessCubit, AdminAccess>(
        'emits only the newest read when tokens come faster than reads',
        setUp: () {
          final slow = Completer<bool>();
          when(() => authRepository.hasAdminClaim(forceRefresh: true))
              .thenAnswer((_) => slow.future);
          when(() => authRepository.hasAdminClaim(forceRefresh: false))
              .thenAnswer((_) async {
                slow.complete(true);
                return false;
              });
        },
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          tokens
            ..add(_member)
            ..add(_member);
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => [AdminAccess.checking, AdminAccess.member],
      );

      blocTest<AdminAccessCubit, AdminAccess>(
        'emits signedOut on sign-out and forces a fresh token again for '
        'whoever signs in next',
        setUp: () =>
            when(() => authRepository.hasAdminClaim(forceRefresh: true))
                .thenAnswer((_) async => true),
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          tokens.add(_owner);
          await Future<void>.delayed(Duration.zero);
          tokens.add(User.empty);
          await Future<void>.delayed(Duration.zero);
          tokens.add(_owner);
        },
        expect: () => [
          AdminAccess.checking,
          AdminAccess.admin,
          AdminAccess.signedOut,
          AdminAccess.checking,
          AdminAccess.admin,
        ],
        verify: (_) =>
            verify(() => authRepository.hasAdminClaim(forceRefresh: true))
                .called(2),
      );

      blocTest<AdminAccessCubit, AdminAccess>(
        'forces a fresh token when another account signs in',
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          tokens.add(_owner);
          await Future<void>.delayed(Duration.zero);
          tokens.add(_member);
        },
        expect: () => [
          AdminAccess.checking,
          AdminAccess.member,
          AdminAccess.checking,
          AdminAccess.member,
        ],
        verify: (_) =>
            verify(() => authRepository.hasAdminClaim(forceRefresh: true))
                .called(2),
      );

      blocTest<AdminAccessCubit, AdminAccess>(
        'emits member and reports it when the token cannot be read',
        setUp: () =>
            when(() => authRepository.hasAdminClaim(forceRefresh: true))
                .thenThrow(const AdminClaimFailure()),
        build: build,
        act: (cubit) {
          cubit.subscribe();
          tokens.add(_owner);
        },
        expect: () => [AdminAccess.checking, AdminAccess.member],
        errors: () => [isA<AdminClaimFailure>()],
      );

      blocTest<AdminAccessCubit, AdminAccess>(
        'emits member and reports it when the token stream fails',
        build: build,
        act: (cubit) {
          cubit.subscribe();
          tokens.addError(Exception('auth'));
        },
        expect: () => [AdminAccess.member],
        errors: () => [isA<Exception>()],
      );

      blocTest<AdminAccessCubit, AdminAccess>(
        'emits nothing once closed while a read is out',
        setUp: () {
          final never = Completer<bool>();
          when(() => authRepository.hasAdminClaim(forceRefresh: true))
              .thenAnswer((_) => never.future);
          addTearDown(() => never.complete(true));
        },
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          tokens.add(_owner);
          await Future<void>.delayed(Duration.zero);
          await cubit.close();
        },
        expect: () => [AdminAccess.checking],
      );
    });
  });
}
