import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/app/app.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

class _MockProfileRepository extends Mock implements ProfileRepository;

class _MockPushRepository extends Mock implements PushRepository;

const _user = User(id: 'demo-uid');

final _tappedAt = DateTime(2026, 10, 27, 18, 30);

final _terms = TermsAcceptance(
  version: AppBloc.termsVersion,
  acceptedAt: _tappedAt,
);

final _profile = Profile(
  firstName: 'Marta',
  ageBand: AgeBand.sixties,
  barrio: Barrio.solymarNorte,
  pretexts: const {Pretext.mate},
  slots: {const Slot(SlotDay.thursday, SlotBand.afternoon)},
  brings: const {Bring.termo},
);

void main() {
  group(AppBloc, () {
    late AuthRepository authRepository;
    late ProfileRepository profileRepository;
    late PushRepository pushRepository;

    setUpAll(() {
      registerFallbackValue(_terms);
    });

    setUp(() {
      authRepository = _MockAuthRepository();
      profileRepository = _MockProfileRepository();
      pushRepository = _MockPushRepository();
      when(() => authRepository.currentUser).thenReturn(User.empty);
      when(() => authRepository.user)
          .thenAnswer((_) => const Stream<User>.empty());
      when(() => profileRepository.watchProfile(any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => profileRepository.acceptTerms(any(), any()))
          .thenAnswer((_) async {});
      when(() => profileRepository.holdTerms(any())).thenAnswer((_) async {});
      when(profileRepository.heldTerms).thenAnswer((_) async => null);
      when(profileRepository.clearHeldTerms).thenAnswer((_) async {});
      when(profileRepository.clearHeldAnswers).thenAnswer((_) async {});
    });

    AppBloc buildBloc() => AppBloc(
      authRepository: authRepository,
      profileRepository: profileRepository,
      pushRepository: pushRepository,
      now: () => _tappedAt,
    );

    test('starts unauthenticated when nobody is signed in', () {
      expect(
        buildBloc().state,
        equals(const AppState(status: AppStatus.unauthenticated)),
      );
    });

    test('starts loading the profile when someone is already signed in', () {
      when(() => authRepository.currentUser).thenReturn(_user);

      expect(
        buildBloc().state,
        equals(const AppState(status: AppStatus.loadingProfile, user: _user)),
      );
    });

    test('reads the clock when none is given', () {
      expect(
        AppBloc(
          authRepository: authRepository,
          profileRepository: profileRepository,
          pushRepository: pushRepository,
        ).state.status,
        equals(AppStatus.unauthenticated),
      );
    });

    test('starts with "¿Cómo funciona?" seen when this phone showed it', () {
      expect(
        AppBloc(
          authRepository: authRepository,
          profileRepository: profileRepository,
          pushRepository: pushRepository,
          walkthroughSeen: true,
        ).state,
        equals(
          const AppState(
            status: AppStatus.unauthenticated,
            walkthroughSeen: true,
          ),
        ),
      );
    });

    group(AppWalkthroughSeen, () {
      blocTest<AppBloc, AppState>(
        'marks it seen, in memory and on this phone',
        setUp: () =>
            when(profileRepository.markWalkthroughSeen)
                .thenAnswer((_) async {}),
        build: buildBloc,
        act: (bloc) => bloc.add(const AppWalkthroughSeen()),
        expect: () => const [
          AppState(status: AppStatus.unauthenticated, walkthroughSeen: true),
        ],
        verify: (_) => verify(profileRepository.markWalkthroughSeen).called(1),
      );

      blocTest<AppBloc, AppState>(
        'emits nothing new when it was already seen',
        setUp: () =>
            when(profileRepository.markWalkthroughSeen)
                .thenAnswer((_) async {}),
        build: buildBloc,
        seed: () => const AppState(
          status: AppStatus.unauthenticated,
          walkthroughSeen: true,
        ),
        act: (bloc) => bloc.add(const AppWalkthroughSeen()),
        expect: () => const <AppState>[],
      );

      blocTest<AppBloc, AppState>(
        'keeps it seen in memory and reports a phone that cannot hold it',
        setUp: () =>
            when(profileRepository.markWalkthroughSeen)
                .thenThrow(const HoldOnPhoneFailure()),
        build: buildBloc,
        act: (bloc) => bloc.add(const AppWalkthroughSeen()),
        expect: () => const [
          AppState(status: AppStatus.unauthenticated, walkthroughSeen: true),
        ],
        errors: () => [isA<HoldOnPhoneFailure>()],
      );
    });

    group(AppSignOutRequested, () {
      setUp(() {
        when(() => authRepository.currentUser).thenReturn(_user);
        when(() => pushRepository.unregisterDevice(any()))
            .thenAnswer((_) async {});
        when(authRepository.signOut).thenAnswer((_) async {});
      });

      blocTest<AppBloc, AppState>(
        "forgets this phone's push token, then signs out",
        build: buildBloc,
        act: (bloc) => bloc.add(const AppSignOutRequested()),
        expect: () => <AppState>[],
        verify: (_) => verifyInOrder([
          () => pushRepository.unregisterDevice('demo-uid'),
          authRepository.signOut,
        ]),
      );

      blocTest<AppBloc, AppState>(
        'signs out and reports it when the token cannot be forgotten',
        setUp: () =>
            when(() => pushRepository.unregisterDevice(any()))
                .thenThrow(const UnregisterDeviceFailure()),
        build: buildBloc,
        act: (bloc) => bloc.add(const AppSignOutRequested()),
        errors: () => [isA<UnregisterDeviceFailure>()],
        verify: (_) => verify(authRepository.signOut).called(1),
      );

      blocTest<AppBloc, AppState>(
        'reports a sign-out that fails',
        setUp: () =>
            when(authRepository.signOut).thenThrow(const SignOutFailure()),
        build: buildBloc,
        act: (bloc) => bloc.add(const AppSignOutRequested()),
        errors: () => [isA<SignOutFailure>()],
      );

      blocTest<AppBloc, AppState>(
        'signs out once when asked twice in a row',
        build: buildBloc,
        act: (bloc) => bloc
          ..add(const AppSignOutRequested())
          ..add(const AppSignOutRequested()),
        verify: (_) {
          verify(() => pushRepository.unregisterDevice('demo-uid')).called(1);
          verify(authRepository.signOut).called(1);
        },
      );

      blocTest<AppBloc, AppState>(
        'does nothing when nobody is signed in',
        setUp: () =>
            when(() => authRepository.currentUser).thenReturn(User.empty),
        build: buildBloc,
        act: (bloc) => bloc.add(const AppSignOutRequested()),
        verify: (_) {
          verifyNever(() => pushRepository.unregisterDevice(any()));
          verifyNever(authRepository.signOut);
        },
      );
    });

    group(AppUserSubscriptionRequested, () {
      blocTest<AppBloc, AppState>(
        'emits loadingProfile then onboarding for someone without a profile',
        setUp: () {
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.value(_user));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
        expect: () => const [
          AppState(status: AppStatus.loadingProfile, user: _user),
          AppState(status: AppStatus.onboarding, user: _user),
        ],
        verify: (_) {
          verify(() => profileRepository.watchProfile('demo-uid')).called(1);
          verifyNever(() => profileRepository.acceptTerms(any(), any()));
        },
      );

      blocTest<AppBloc, AppState>(
        'emits authenticated once the profile arrives',
        setUp: () {
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.value(_user));
          when(() => profileRepository.watchProfile('demo-uid'))
              .thenAnswer((_) => Stream.fromIterable([null, _profile]));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
        expect: () => const [
          AppState(status: AppStatus.loadingProfile, user: _user),
          AppState(status: AppStatus.onboarding, user: _user),
          AppState(status: AppStatus.authenticated, user: _user),
        ],
        verify: (_) {
          verify(profileRepository.clearHeldAnswers).called(1);
        },
      );

      blocTest<AppBloc, AppState>(
        'stops holding answers once, however often the profile changes',
        setUp: () {
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.value(_user));
          when(() => profileRepository.watchProfile('demo-uid'))
              .thenAnswer((_) => Stream.fromIterable([_profile, _profile]));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
        verify: (_) {
          verify(profileRepository.clearHeldAnswers).called(1);
        },
      );

      blocTest<AppBloc, AppState>(
        'adds the error when the held answers cannot be cleared',
        setUp: () {
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.value(_user));
          when(() => profileRepository.watchProfile('demo-uid'))
              .thenAnswer((_) => Stream.value(_profile));
          when(profileRepository.clearHeldAnswers)
              .thenThrow(const HoldOnPhoneFailure());
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
        expect: () => const [
          AppState(status: AppStatus.loadingProfile, user: _user),
          AppState(status: AppStatus.authenticated, user: _user),
        ],
        errors: () => [isA<HoldOnPhoneFailure>()],
      );

      blocTest<AppBloc, AppState>(
        'writes the acceptance held on the phone when none is in memory, '
        'then stops holding it',
        setUp: () {
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.value(_user));
          when(profileRepository.heldTerms).thenAnswer((_) async => _terms);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
        expect: () => const [
          AppState(status: AppStatus.loadingProfile, user: _user),
          AppState(status: AppStatus.onboarding, user: _user),
        ],
        verify: (_) {
          verify(() => profileRepository.acceptTerms('demo-uid', _terms))
              .called(1);
          verify(profileRepository.clearHeldTerms).called(1);
        },
      );

      blocTest<AppBloc, AppState>(
        'adds the error, and moves on, when the held acceptance cannot be '
        'cleared',
        setUp: () {
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.value(_user));
          when(profileRepository.heldTerms).thenAnswer((_) async => _terms);
          when(profileRepository.clearHeldTerms)
              .thenThrow(const HoldOnPhoneFailure());
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
        expect: () => const [
          AppState(status: AppStatus.loadingProfile, user: _user),
          AppState(status: AppStatus.onboarding, user: _user),
        ],
        errors: () => [isA<HoldOnPhoneFailure>()],
      );

      blocTest<AppBloc, AppState>(
        'emits unauthenticated when the person signs out, and stops '
        'following the old profile',
        setUp: () {
          final users = StreamController<User>();
          final profiles = StreamController<Profile?>.broadcast();
          addTearDown(users.close);
          addTearDown(profiles.close);
          when(() => authRepository.user).thenAnswer((_) => users.stream);
          when(() => profileRepository.watchProfile('demo-uid'))
              .thenAnswer((_) => profiles.stream);
          unawaited(
            Future(() async {
              users.add(_user);
              await Future<void>.delayed(Duration.zero);
              profiles.add(null);
              await Future<void>.delayed(Duration.zero);
              users.add(User.empty);
              await Future<void>.delayed(Duration.zero);
              profiles.add(_profile);
            }),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
        wait: const Duration(milliseconds: 10),
        expect: () => const [
          AppState(status: AppStatus.loadingProfile, user: _user),
          AppState(status: AppStatus.onboarding, user: _user),
          AppState(status: AppStatus.unauthenticated),
        ],
      );

      blocTest<AppBloc, AppState>(
        'adds the error when the user stream fails',
        setUp: () {
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.error(Exception('boom')));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
        expect: () => const <AppState>[],
        errors: () => [isA<Exception>()],
      );

      blocTest<AppBloc, AppState>(
        'adds the error when the profile stream fails',
        setUp: () {
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.value(_user));
          when(() => profileRepository.watchProfile('demo-uid'))
              .thenAnswer((_) => Stream.error(Exception('permission-denied')));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
        expect: () => const [
          AppState(status: AppStatus.loadingProfile, user: _user),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group(AppTermsAccepted, () {
      blocTest<AppBloc, AppState>(
        'holds the acceptance in memory and on the phone while nobody is '
        'signed in, writing nothing',
        build: buildBloc,
        act: (bloc) => bloc.add(const AppTermsAccepted()),
        expect: () => [
          AppState(status: AppStatus.unauthenticated, pendingTerms: _terms),
        ],
        verify: (_) {
          verify(() => profileRepository.holdTerms(_terms)).called(1);
          verifyNever(() => profileRepository.acceptTerms(any(), any()));
        },
      );

      blocTest<AppBloc, AppState>(
        'keeps the acceptance in memory, adding the error, when the phone '
        'cannot hold it',
        setUp: () {
          when(() => profileRepository.holdTerms(any()))
              .thenThrow(const HoldOnPhoneFailure());
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AppTermsAccepted()),
        expect: () => [
          AppState(status: AppStatus.unauthenticated, pendingTerms: _terms),
        ],
        errors: () => [isA<HoldOnPhoneFailure>()],
      );

      blocTest<AppBloc, AppState>(
        'writes the held acceptance once the person signs in',
        setUp: () {
          final users = StreamController<User>();
          addTearDown(users.close);
          when(() => authRepository.user).thenAnswer((_) => users.stream);
          unawaited(
            Future(() async {
              await Future<void>.delayed(Duration.zero);
              users.add(_user);
            }),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc
          ..add(const AppTermsAccepted())
          ..add(const AppUserSubscriptionRequested()),
        wait: const Duration(milliseconds: 10),
        expect: () => [
          AppState(status: AppStatus.unauthenticated, pendingTerms: _terms),
          AppState(
            status: AppStatus.loadingProfile,
            user: _user,
            pendingTerms: _terms,
          ),
          const AppState(status: AppStatus.loadingProfile, user: _user),
          const AppState(status: AppStatus.onboarding, user: _user),
        ],
        verify: (_) {
          verify(() => profileRepository.acceptTerms('demo-uid', _terms))
              .called(1);
          verify(profileRepository.clearHeldTerms).called(1);
          verifyNever(profileRepository.heldTerms);
        },
      );

      blocTest<AppBloc, AppState>(
        'keeps the acceptance held, and moves on, when writing it fails',
        setUp: () {
          when(() => profileRepository.acceptTerms(any(), any()))
              .thenThrow(const AcceptTermsFailure());
          final users = StreamController<User>();
          addTearDown(users.close);
          when(() => authRepository.user).thenAnswer((_) => users.stream);
          unawaited(
            Future(() async {
              await Future<void>.delayed(Duration.zero);
              users.add(_user);
            }),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc
          ..add(const AppTermsAccepted())
          ..add(const AppUserSubscriptionRequested()),
        wait: const Duration(milliseconds: 10),
        expect: () => [
          AppState(status: AppStatus.unauthenticated, pendingTerms: _terms),
          AppState(
            status: AppStatus.loadingProfile,
            user: _user,
            pendingTerms: _terms,
          ),
          AppState(
            status: AppStatus.onboarding,
            user: _user,
            pendingTerms: _terms,
          ),
        ],
        errors: () => [isA<AcceptTermsFailure>()],
      );

      blocTest<AppBloc, AppState>(
        'writes the acceptance at once when someone is signed in',
        setUp: () {
          when(() => authRepository.currentUser).thenReturn(_user);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AppTermsAccepted()),
        expect: () => const <AppState>[],
        verify: (_) {
          verify(() => profileRepository.acceptTerms('demo-uid', _terms))
              .called(1);
        },
      );

      blocTest<AppBloc, AppState>(
        'remembers the voice door across sign-in',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const AppTermsAccepted(door: OnboardingDoor.voice)),
        expect: () => [
          AppState(
            status: AppStatus.unauthenticated,
            pendingTerms: _terms,
            door: OnboardingDoor.voice,
          ),
        ],
      );

      blocTest<AppBloc, AppState>(
        'switches the door when someone signed in taps another',
        setUp: () {
          when(() => authRepository.currentUser).thenReturn(_user);
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const AppTermsAccepted(door: OnboardingDoor.voice)),
        expect: () => const [
          AppState(
            status: AppStatus.loadingProfile,
            user: _user,
            door: OnboardingDoor.voice,
          ),
        ],
      );

      blocTest<AppBloc, AppState>(
        'adds the error when writing at once fails',
        setUp: () {
          when(() => authRepository.currentUser).thenReturn(_user);
          when(() => profileRepository.acceptTerms(any(), any()))
              .thenThrow(const AcceptTermsFailure());
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AppTermsAccepted()),
        expect: () => const <AppState>[],
        errors: () => [isA<AcceptTermsFailure>()],
      );
    });
  });

  group(AppState, () {
    group('fromUser', () {
      test('is unauthenticated for ${User.empty}', () {
        expect(
          AppState.fromUser(User.empty),
          equals(const AppState(status: AppStatus.unauthenticated)),
        );
      });

      test('is loading the profile for a signed-in $User', () {
        expect(
          AppState.fromUser(_user),
          equals(const AppState(status: AppStatus.loadingProfile, user: _user)),
        );
      });
    });

    test('withDoor keeps everything else', () {
      expect(
        AppState(
          status: AppStatus.onboarding,
          user: _user,
          pendingTerms: _terms,
        ).withDoor(OnboardingDoor.voice),
        equals(
          AppState(
            status: AppStatus.onboarding,
            user: _user,
            pendingTerms: _terms,
            door: OnboardingDoor.voice,
          ),
        ),
      );
    });

    test('withStatus keeps the user and the held terms', () {
      expect(
        AppState(
          status: AppStatus.loadingProfile,
          user: _user,
          pendingTerms: _terms,
        ).withStatus(AppStatus.onboarding),
        equals(
          AppState(
            status: AppStatus.onboarding,
            user: _user,
            pendingTerms: _terms,
          ),
        ),
      );
    });
  });

  group('AppState.withWalkthroughSeen', () {
    test('keeps everything else', () {
      expect(
        AppState(
          status: AppStatus.onboarding,
          user: _user,
          pendingTerms: _terms,
          door: OnboardingDoor.voice,
        ).withWalkthroughSeen(),
        equals(
          AppState(
            status: AppStatus.onboarding,
            user: _user,
            pendingTerms: _terms,
            door: OnboardingDoor.voice,
            walkthroughSeen: true,
          ),
        ),
      );
    });
  });

  group(AppEvent, () {
    test('carries the door as its only prop', () {
      expect(const AppUserSubscriptionRequested().props, isEmpty);
      expect(const AppSignOutRequested().props, isEmpty);
      expect(const AppWalkthroughSeen().props, isEmpty);
      expect(
        const AppTermsAccepted(door: OnboardingDoor.voice).props,
        equals([OnboardingDoor.voice]),
      );
    });
  });
}
