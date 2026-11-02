import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/app.dart';

class _MockProfileRepository extends Mock implements ProfileRepository;

void main() {
  group(LanguageCubit, () {
    late ProfileRepository profileRepository;

    setUp(() {
      profileRepository = _MockProfileRepository();
      when(() => profileRepository.holdLanguage(any()))
          .thenAnswer((_) async {});
    });

    setUpAll(() => registerFallbackValue(AppLanguage.spanish));

    test('starts in the language read before the app started', () {
      expect(
        LanguageCubit(
          profileRepository: profileRepository,
          initial: AppLanguage.english,
        ).state,
        const LanguageState(language: AppLanguage.english),
      );
    });

    blocTest<LanguageCubit, LanguageState>(
      'switches to the picked language and keeps it on the phone',
      build: () => LanguageCubit(profileRepository: profileRepository),
      act: (cubit) => cubit.languagePicked(AppLanguage.english),
      expect: () => [const LanguageState(language: AppLanguage.english)],
      verify: (_) =>
          verify(() => profileRepository.holdLanguage(AppLanguage.english))
              .called(1),
    );

    blocTest<LanguageCubit, LanguageState>(
      'goes back to the phone language with null',
      build: () => LanguageCubit(
        profileRepository: profileRepository,
        initial: AppLanguage.spanish,
      ),
      act: (cubit) => cubit.languagePicked(null),
      expect: () => [const LanguageState()],
      verify: (_) =>
          verify(() => profileRepository.holdLanguage(null)).called(1),
    );

    blocTest<LanguageCubit, LanguageState>(
      'still switches when the phone cannot keep the pick',
      setUp: () =>
          when(() => profileRepository.holdLanguage(any()))
              .thenThrow(const HoldOnPhoneFailure()),
      build: () => LanguageCubit(profileRepository: profileRepository),
      act: (cubit) => cubit.languagePicked(AppLanguage.english),
      expect: () => [const LanguageState(language: AppLanguage.english)],
    );
  });
}
