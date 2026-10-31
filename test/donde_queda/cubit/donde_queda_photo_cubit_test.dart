import 'package:bloc_test/bloc_test.dart';
import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/donde_queda/cubit/donde_queda_photo_cubit.dart';
import 'package:ronda/donde_queda/models/game_text.dart';

import '../fixtures.dart';

class _MockDondeQuedaRepository extends Mock implements DondeQuedaRepository;

void main() {
  group(DondeQuedaPhotoCubit, () {
    late DondeQuedaRepository repository;

    const taken = TakenPhoto.test();
    final blurred = BlurredPhoto.test(blurredFaces: 1);
    final retouched = BlurredPhoto.test(blurredFaces: 2);
    final game = DondeQuedaFixtures.game();

    setUpAll(() {
      registerFallbackValue(PhotoSource.camera);
      registerFallbackValue(const TakenPhoto.test());
      registerFallbackValue(BlurredPhoto.test());
      registerFallbackValue(DondeQuedaFixtures.pin);
    });

    void watching(DondeQuedaWeek week) => when(
      () => repository.watch(
        rondaId: DondeQuedaFixtures.rondaId,
        uid: DondeQuedaFixtures.uid,
      ),
    ).thenAnswer((_) => Stream.value(week));

    setUp(() {
      repository = _MockDondeQuedaRepository();
      watching(DondeQuedaWeek(game: game));
      when(() => repository.canBlurFaces).thenReturn(true);
      when(repository.retrieveLostPhoto).thenAnswer((_) async => null);
      when(() => repository.takePhoto(any())).thenAnswer((_) async => taken);
      when(() => repository.blur(taken)).thenAnswer((_) async => blurred);
    });

    DondeQuedaPhotoCubit build() => DondeQuedaPhotoCubit(
      uid: DondeQuedaFixtures.uid,
      rondaId: DondeQuedaFixtures.rondaId,
      dondeQuedaRepository: repository,
    );

    DondeQuedaPhotoState at(
      DondeQuedaPhotoStatus status, {
      BlurredPhoto? photo,
      GameText line = const GameText.pure(),
      GameText hint = const GameText.pure(optional: true),
      MapPoint? pin,
      DondeQuedaPhotoFailure? failure,
    }) => DondeQuedaPhotoState(
      status: status,
      game: game,
      photo: photo,
      line: line,
      hint: hint,
      pin: pin,
      failure: failure,
    );

    DondeQuedaPhotoCubit seeded(DondeQuedaPhotoState state) =>
        build()..emit(state);

    group('started', () {
      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'waits for a photo when it is their turn',
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => [at(DondeQuedaPhotoStatus.choosing)],
      );

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'blurs a photo the camera took while the app was stopped',
        setUp: () =>
            when(repository.retrieveLostPhoto).thenAnswer((_) async => taken),
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => [
          at(DondeQuedaPhotoStatus.choosing),
          at(DondeQuedaPhotoStatus.blurring),
          at(DondeQuedaPhotoStatus.preview, photo: blurred),
        ],
      );

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'says so on web',
        setUp: () => when(() => repository.canBlurFaces).thenReturn(false),
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => [at(DondeQuedaPhotoStatus.unsupported)],
      );

      for (final week in [
        const DondeQuedaWeek(),
        DondeQuedaWeek(game: DondeQuedaFixtures.open()),
      ]) {
        blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
          'closes when it is not their turn: ${week.game?.status}',
          setUp: () => watching(week),
          build: build,
          act: (cubit) => cubit.started(),
          expect: () => const [
            DondeQuedaPhotoState(status: DondeQuedaPhotoStatus.closed),
          ],
        );
      }

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'closes when the game cannot be read',
        setUp: () => when(
          () => repository.watch(
            rondaId: any(named: 'rondaId'),
            uid: any(named: 'uid'),
          ),
        ).thenAnswer((_) => Stream.error(Exception('denied'))),
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => const [
          DondeQuedaPhotoState(status: DondeQuedaPhotoStatus.closed),
        ],
        errors: () => [isException],
      );
    });

    group('photoRequested', () {
      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'blurs the faces of the photo taken',
        build: () => seeded(at(DondeQuedaPhotoStatus.choosing)),
        act: (cubit) => cubit.photoRequested(PhotoSource.gallery),
        expect: () => [
          at(DondeQuedaPhotoStatus.blurring),
          at(DondeQuedaPhotoStatus.preview, photo: blurred),
        ],
        verify: (_) =>
            verify(() => repository.takePhoto(PhotoSource.gallery)).called(1),
      );

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'stays when the person backs out',
        setUp: () =>
            when(() => repository.takePhoto(any()))
                .thenAnswer((_) async => null),
        build: () => seeded(at(DondeQuedaPhotoStatus.choosing)),
        act: (cubit) => cubit.photoRequested(PhotoSource.camera),
        expect: () => const <DondeQuedaPhotoState>[],
      );

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'says when the camera did not open',
        setUp: () =>
            when(() => repository.takePhoto(any()))
                .thenThrow(const TakePhotoFailure()),
        build: () => seeded(at(DondeQuedaPhotoStatus.choosing)),
        act: (cubit) => cubit.photoRequested(PhotoSource.camera),
        expect: () => [
          at(
            DondeQuedaPhotoStatus.choosing,
            failure: DondeQuedaPhotoFailure.photo,
          ),
        ],
      );

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'says when the photo could not be blurred',
        setUp: () =>
            when(() => repository.blur(any()))
                .thenThrow(const BlurPhotoFailure()),
        build: () => seeded(at(DondeQuedaPhotoStatus.choosing)),
        act: (cubit) => cubit.photoRequested(PhotoSource.camera),
        expect: () => [
          at(DondeQuedaPhotoStatus.blurring),
          at(
            DondeQuedaPhotoStatus.choosing,
            failure: DondeQuedaPhotoFailure.photo,
          ),
        ],
      );

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'does nothing outside the camera step',
        build: () => seeded(at(DondeQuedaPhotoStatus.preview, photo: blurred)),
        act: (cubit) => cubit.photoRequested(PhotoSource.camera),
        expect: () => const <DondeQuedaPhotoState>[],
      );
    });

    group('faceTapped', () {
      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'blurs the face the detector missed',
        setUp: () =>
            when(() => repository.blurTappedFace(blurred, x: 0.2, y: 0.3))
                .thenAnswer((_) async => retouched),
        build: () => seeded(at(DondeQuedaPhotoStatus.preview, photo: blurred)),
        act: (cubit) => cubit.faceTapped(x: 0.2, y: 0.3),
        expect: () => [
          at(DondeQuedaPhotoStatus.blurring, photo: blurred),
          at(DondeQuedaPhotoStatus.preview, photo: retouched),
        ],
      );

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'keeps the photo and says when it failed',
        setUp: () => when(
          () => repository.blurTappedFace(
            any(),
            x: any(named: 'x'),
            y: any(named: 'y'),
          ),
        ).thenThrow(const BlurPhotoFailure()),
        build: () => seeded(at(DondeQuedaPhotoStatus.preview, photo: blurred)),
        act: (cubit) => cubit.faceTapped(x: 0, y: 0),
        expect: () => [
          at(DondeQuedaPhotoStatus.blurring, photo: blurred),
          at(
            DondeQuedaPhotoStatus.preview,
            photo: blurred,
            failure: DondeQuedaPhotoFailure.photo,
          ),
        ],
      );

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'does nothing without a photo',
        build: () => seeded(at(DondeQuedaPhotoStatus.choosing)),
        act: (cubit) => cubit.faceTapped(x: 0, y: 0),
        expect: () => const <DondeQuedaPhotoState>[],
      );
    });

    group('the words', () {
      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'keep what was typed, and go on to the map once valid',
        build: () => seeded(at(DondeQuedaPhotoStatus.preview, photo: blurred)),
        act: (cubit) => cubit
          ..lineChanged('la puerta verde')
          ..hintChanged('cerca de la feria')
          ..wordsDone(),
        expect: () => [
          at(
            DondeQuedaPhotoStatus.preview,
            photo: blurred,
            line: const GameText.dirty('la puerta verde'),
          ),
          at(
            DondeQuedaPhotoStatus.preview,
            photo: blurred,
            line: const GameText.dirty('la puerta verde'),
            hint: const GameText.dirty('cerca de la feria', optional: true),
          ),
          at(
            DondeQuedaPhotoStatus.pinning,
            photo: blurred,
            line: const GameText.dirty('la puerta verde'),
            hint: const GameText.dirty('cerca de la feria', optional: true),
          ),
        ],
      );

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'show what is missing instead of going on',
        build: () => seeded(at(DondeQuedaPhotoStatus.preview, photo: blurred)),
        act: (cubit) => cubit.wordsDone(),
        expect: () => [
          at(
            DondeQuedaPhotoStatus.preview,
            photo: blurred,
            line: const GameText.dirty(''),
          ),
        ],
      );

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'do nothing outside the preview',
        build: () => seeded(at(DondeQuedaPhotoStatus.choosing)),
        act: (cubit) => cubit.wordsDone(),
        expect: () => const <DondeQuedaPhotoState>[],
      );
    });

    group('the map', () {
      final words = at(
        DondeQuedaPhotoStatus.pinning,
        photo: blurred,
        line: const GameText.dirty('la puerta verde'),
      );

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'takes the pin, and goes back to the words',
        build: () => seeded(words),
        act: (cubit) => cubit
          ..pinDropped(DondeQuedaFixtures.pin)
          ..backToWords()
          ..pinDropped(DondeQuedaFixtures.centre)
          ..backToWords(),
        expect: () => [
          words.copyWith(pin: () => DondeQuedaFixtures.pin),
          words.copyWith(
            status: DondeQuedaPhotoStatus.preview,
            pin: () => DondeQuedaFixtures.pin,
          ),
        ],
      );
    });

    group('sendTapped', () {
      final ready = at(
        DondeQuedaPhotoStatus.pinning,
        photo: blurred,
        line: const GameText.dirty(' la puerta  verde '),
        hint: const GameText.dirty('', optional: true),
        pin: DondeQuedaFixtures.pin,
      );

      void posting(Exception? error) =>
          when(
            () => repository.post(
              uid: any(named: 'uid'),
              rondaId: any(named: 'rondaId'),
              week: any(named: 'week'),
              photo: any(named: 'photo'),
              line: any(named: 'line'),
              hint: any(named: 'hint'),
              pin: any(named: 'pin'),
            ),
          ).thenAnswer((_) async {
            if (error != null) throw error;
          });

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'posts the blurred photo, the words and the pin',
        setUp: () => posting(null),
        build: () => seeded(ready),
        act: (cubit) => cubit.sendTapped(),
        expect: () => [
          ready.copyWith(status: DondeQuedaPhotoStatus.sending),
          ready.copyWith(status: DondeQuedaPhotoStatus.done),
        ],
        verify: (_) => verify(
          () => repository.post(
            uid: DondeQuedaFixtures.uid,
            rondaId: DondeQuedaFixtures.rondaId,
            week: DondeQuedaFixtures.week,
            photo: blurred,
            line: 'la puerta verde',
            hint: '',
            pin: DondeQuedaFixtures.pin,
          ),
        ).called(1),
      );

      for (final (refusal, failure) in [
        (PhotoRefusal.houseNumber, DondeQuedaPhotoFailure.houseNumber),
        (PhotoRefusal.person, DondeQuedaPhotoFailure.person),
        (PhotoRefusal.empty, DondeQuedaPhotoFailure.empty),
      ]) {
        blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
          'asks for another photo when refused: $refusal',
          setUp: () => posting(PhotoRefusedFailure(refusal)),
          build: () => seeded(ready),
          act: (cubit) => cubit.sendTapped(),
          expect: () => [
            ready.copyWith(status: DondeQuedaPhotoStatus.sending),
            ready.copyWith(
              status: DondeQuedaPhotoStatus.choosing,
              photo: () => null,
              pin: () => null,
              failure: () => failure,
            ),
          ],
        );
      }

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'goes back to the words when they are refused',
        setUp: () => posting(const PhotoRefusedFailure(PhotoRefusal.words)),
        build: () => seeded(ready),
        act: (cubit) => cubit.sendTapped(),
        expect: () => [
          ready.copyWith(status: DondeQuedaPhotoStatus.sending),
          ready.copyWith(
            status: DondeQuedaPhotoStatus.preview,
            failure: () => DondeQuedaPhotoFailure.words,
          ),
        ],
      );

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'closes when the turn passed on',
        setUp: () => posting(const NotYourTurnFailure()),
        build: () => seeded(ready),
        act: (cubit) => cubit.sendTapped(),
        expect: () => [
          ready.copyWith(status: DondeQuedaPhotoStatus.sending),
          const DondeQuedaPhotoState(status: DondeQuedaPhotoStatus.closed),
        ],
      );

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'stays on the map and says when it failed',
        setUp: () => posting(const DondeQuedaFailure()),
        build: () => seeded(ready),
        act: (cubit) => cubit.sendTapped(),
        expect: () => [
          ready.copyWith(status: DondeQuedaPhotoStatus.sending),
          ready.copyWith(failure: () => DondeQuedaPhotoFailure.send),
        ],
        errors: () => [isA<DondeQuedaFailure>()],
      );

      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'does nothing without a pin',
        build: () => seeded(ready.copyWith(pin: () => null)),
        act: (cubit) => cubit.sendTapped(),
        expect: () => const <DondeQuedaPhotoState>[],
      );
    });

    group('retakeRequested', () {
      blocTest<DondeQuedaPhotoCubit, DondeQuedaPhotoState>(
        'goes back to the camera, keeping the words',
        build: () => seeded(
          at(
            DondeQuedaPhotoStatus.preview,
            photo: blurred,
            line: const GameText.dirty('x'),
          ),
        ),
        act: (cubit) => cubit
          ..retakeRequested()
          ..retakeRequested(),
        expect: () => [
          at(DondeQuedaPhotoStatus.choosing, line: const GameText.dirty('x')),
        ],
      );
    });
  });
}
