import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app/cubit/unread_reports_cubit.dart';
import 'package:safety_repository/safety_repository.dart';

class _MockSafetyRepository extends Mock implements SafetyRepository;

void main() {
  group(UnreadReportsCubit, () {
    late SafetyRepository repository;

    setUp(() {
      repository = _MockSafetyRepository();
      when(repository.watchUnreadCount)
          .thenAnswer((_) => Stream.fromIterable([2, 3]));
    });

    UnreadReportsCubit build() =>
        UnreadReportsCubit(safetyRepository: repository);

    test('starts at 0 and asks nothing', () {
      expect(build().state, equals(0));
      verifyNever(repository.watchUnreadCount);
    });

    blocTest<UnreadReportsCubit, int>(
      'follows the count for the admin',
      build: build,
      act: (cubit) => cubit.follow(admin: true),
      expect: () => [2, 3],
    );

    blocTest<UnreadReportsCubit, int>(
      'goes back to 0 and stops reading when the account is not the admin',
      build: build,
      seed: () => 4,
      act: (cubit) => cubit.follow(admin: false),
      expect: () => [0],
      verify: (_) => verifyNever(repository.watchUnreadCount),
    );

    blocTest<UnreadReportsCubit, int>(
      'a refused read counts as 0',
      setUp: () => when(repository.watchUnreadCount).thenAnswer(
        (_) => Stream.error(const SafetyFailure(SafetyFailureReason.forbidden)),
      ),
      build: build,
      seed: () => 4,
      act: (cubit) => cubit.follow(admin: true),
      expect: () => [0],
      errors: () => [isA<SafetyFailure>()],
    );
  });
}
