import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyer_repository/flyer_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/mate_flyer/mate_flyer.dart';

class _MockFlyerRepository extends Mock implements FlyerRepository;

void main() {
  group(MateFlyerCubit, () {
    late FlyerRepository repository;

    const taken = TakenPhoto.test();
    final photo = BlurredPhoto.test(blurredFaces: 1);
    final tapped = BlurredPhoto.test(blurredFaces: 2);
    final flyer = MateFlyer(
      id: 'flyer-1',
      image: Uint8List.fromList([1]),
      landingUrl: 'https://ronda-uy.web.app/f/flyer-1',
    );
    final preview = MateFlyerState(
      status: MateFlyerStatus.preview,
      photo: photo,
    );
    final ready = MateFlyerState(status: MateFlyerStatus.ready, flyer: flyer);

    setUpAll(() {
      registerFallbackValue(PhotoSource.camera);
      registerFallbackValue(const TakenPhoto.test());
      registerFallbackValue(BlurredPhoto.test());
      registerFallbackValue(flyer);
    });

    setUp(() {
      repository = _MockFlyerRepository();
      when(() => repository.canBlurFaces).thenReturn(true);
      when(repository.retrieveLostPhoto).thenAnswer((_) async => null);
      when(() => repository.takePhoto(any())).thenAnswer((_) async => taken);
      when(() => repository.blur(taken)).thenAnswer((_) async => photo);
      when(
        () => repository.blurTappedFace(
          any(),
          x: any(named: 'x'),
          y: any(named: 'y'),
        ),
      ).thenAnswer((_) async => tapped);
      when(
        () => repository.makeMateFlyer(
          uid: any(named: 'uid'),
          rondaId: any(named: 'rondaId'),
          photo: any(named: 'photo'),
        ),
      ).thenAnswer((_) async => flyer);
      when(() => repository.shareFlyer(any(), title: any(named: 'title')))
          .thenAnswer((_) async => true);
    });

    MateFlyerCubit build() => MateFlyerCubit(
      uid: 'demo-uid',
      rondaId: 'ronda-1',
      flyerRepository: repository,
    );

    test('starts waiting for a photo where faces can be blurred', () {
      expect(build().state, equals(const MateFlyerState()));
    });

    test('starts unsupported on web', () {
      when(() => repository.canBlurFaces).thenReturn(false);

      expect(
        build().state,
        equals(const MateFlyerState(status: MateFlyerStatus.unsupported)),
      );
    });

    group('started', () {
      blocTest<MateFlyerCubit, MateFlyerState>(
        'blurs a photo the camera took while the app was stopped',
        setUp: () =>
            when(repository.retrieveLostPhoto).thenAnswer((_) async => taken),
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => [
          const MateFlyerState(status: MateFlyerStatus.blurring),
          preview,
        ],
      );

      blocTest<MateFlyerCubit, MateFlyerState>(
        'stays put when nothing was lost',
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => <MateFlyerState>[],
      );

      blocTest<MateFlyerCubit, MateFlyerState>(
        'looks for nothing on web',
        setUp: () => when(() => repository.canBlurFaces).thenReturn(false),
        build: build,
        act: (cubit) => cubit.started(),
        verify: (_) => verifyNever(repository.retrieveLostPhoto),
      );
    });

    group('photoRequested', () {
      blocTest<MateFlyerCubit, MateFlyerState>(
        'takes the photo and shows it blurred',
        build: build,
        act: (cubit) => cubit.photoRequested(PhotoSource.gallery),
        expect: () => [
          const MateFlyerState(status: MateFlyerStatus.blurring),
          preview,
        ],
        verify: (_) =>
            verify(() => repository.takePhoto(PhotoSource.gallery)).called(1),
      );

      blocTest<MateFlyerCubit, MateFlyerState>(
        'clears a failure and waits again when the person backs out',
        setUp: () =>
            when(() => repository.takePhoto(any()))
                .thenAnswer((_) async => null),
        build: build,
        seed: () => const MateFlyerState(failure: MateFlyerFailure.photo),
        act: (cubit) => cubit.photoRequested(PhotoSource.camera),
        expect: () => [const MateFlyerState()],
      );

      blocTest<MateFlyerCubit, MateFlyerState>(
        'says the photo failed when the camera does',
        setUp: () =>
            when(() => repository.takePhoto(any()))
                .thenThrow(const TakePhotoFailure()),
        build: build,
        act: (cubit) => cubit.photoRequested(PhotoSource.camera),
        expect: () => [const MateFlyerState(failure: MateFlyerFailure.photo)],
      );

      blocTest<MateFlyerCubit, MateFlyerState>(
        'says the photo failed when blurring does',
        setUp: () =>
            when(() => repository.blur(any()))
                .thenThrow(const BlurPhotoFailure()),
        build: build,
        act: (cubit) => cubit.photoRequested(PhotoSource.camera),
        expect: () => [
          const MateFlyerState(status: MateFlyerStatus.blurring),
          const MateFlyerState(failure: MateFlyerFailure.photo),
        ],
      );

      blocTest<MateFlyerCubit, MateFlyerState>(
        'does nothing past the photo step',
        build: build,
        seed: () => preview,
        act: (cubit) => cubit.photoRequested(PhotoSource.camera),
        expect: () => <MateFlyerState>[],
      );
    });

    group('faceTapped', () {
      blocTest<MateFlyerCubit, MateFlyerState>(
        'blurs the tapped face too',
        build: build,
        seed: () => preview,
        act: (cubit) => cubit.faceTapped(x: 0.25, y: 0.5),
        expect: () => [
          MateFlyerState(status: MateFlyerStatus.blurring, photo: photo),
          MateFlyerState(status: MateFlyerStatus.preview, photo: tapped),
        ],
        verify: (_) =>
            verify(() => repository.blurTappedFace(photo, x: 0.25, y: 0.5))
                .called(1),
      );

      blocTest<MateFlyerCubit, MateFlyerState>(
        'keeps the photo and says so when that fails',
        setUp: () => when(
          () => repository.blurTappedFace(
            any(),
            x: any(named: 'x'),
            y: any(named: 'y'),
          ),
        ).thenThrow(const BlurPhotoFailure()),
        build: build,
        seed: () => preview,
        act: (cubit) => cubit.faceTapped(x: 0, y: 0),
        expect: () => [
          MateFlyerState(status: MateFlyerStatus.blurring, photo: photo),
          MateFlyerState(
            status: MateFlyerStatus.preview,
            photo: photo,
            failure: MateFlyerFailure.photo,
          ),
        ],
      );

      blocTest<MateFlyerCubit, MateFlyerState>(
        'does nothing without a preview',
        build: build,
        act: (cubit) => cubit.faceTapped(x: 0, y: 0),
        expect: () => <MateFlyerState>[],
      );
    });

    group('flyerRequested', () {
      blocTest<MateFlyerCubit, MateFlyerState>(
        'sends the blurred photo and shows the flyer',
        build: build,
        seed: () => preview,
        act: (cubit) => cubit.flyerRequested(),
        expect: () => [
          MateFlyerState(status: MateFlyerStatus.making, photo: photo),
          ready,
        ],
        verify: (_) => verify(
          () => repository.makeMateFlyer(
            uid: 'demo-uid',
            rondaId: 'ronda-1',
            photo: photo,
          ),
        ).called(1),
      );

      for (final (thrown, failure) in [
        (const NotAHostFailure(), MateFlyerFailure.notHost),
        (const MakeFlyerFailure(), MateFlyerFailure.flyer),
      ]) {
        blocTest<MateFlyerCubit, MateFlyerState>(
          'keeps the photo and says ${failure.name} on ${thrown.runtimeType}',
          setUp: () => when(
            () => repository.makeMateFlyer(
              uid: any(named: 'uid'),
              rondaId: any(named: 'rondaId'),
              photo: any(named: 'photo'),
            ),
          ).thenThrow(thrown),
          build: build,
          seed: () => preview,
          act: (cubit) => cubit.flyerRequested(),
          expect: () => [
            MateFlyerState(status: MateFlyerStatus.making, photo: photo),
            MateFlyerState(
              status: MateFlyerStatus.preview,
              photo: photo,
              failure: failure,
            ),
          ],
        );
      }

      blocTest<MateFlyerCubit, MateFlyerState>(
        'asks for another photo when nothing could be cut out',
        setUp: () => when(
          () => repository.makeMateFlyer(
            uid: any(named: 'uid'),
            rondaId: any(named: 'rondaId'),
            photo: any(named: 'photo'),
          ),
        ).thenThrow(const NothingToCutOutFailure()),
        build: build,
        seed: () => preview,
        act: (cubit) => cubit.flyerRequested(),
        expect: () => [
          MateFlyerState(status: MateFlyerStatus.making, photo: photo),
          const MateFlyerState(failure: MateFlyerFailure.nothingToCutOut),
        ],
      );

      blocTest<MateFlyerCubit, MateFlyerState>(
        'does nothing without a preview',
        build: build,
        act: (cubit) => cubit.flyerRequested(),
        expect: () => <MateFlyerState>[],
      );
    });

    group('shareRequested', () {
      blocTest<MateFlyerCubit, MateFlyerState>(
        'opens the share sheet with the flyer',
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.shareRequested(title: 'Un mate de más'),
        expect: () => <MateFlyerState>[],
        verify: (_) =>
            verify(() => repository.shareFlyer(flyer, title: 'Un mate de más'))
                .called(1),
      );

      blocTest<MateFlyerCubit, MateFlyerState>(
        'clears an earlier share failure first',
        build: build,
        seed: () => MateFlyerState(
          status: MateFlyerStatus.ready,
          flyer: flyer,
          failure: MateFlyerFailure.share,
        ),
        act: (cubit) => cubit.shareRequested(title: 't'),
        expect: () => [ready],
      );

      blocTest<MateFlyerCubit, MateFlyerState>(
        'says so when the sheet fails',
        setUp: () =>
            when(() => repository.shareFlyer(any(), title: any(named: 'title')))
                .thenThrow(const ShareFlyerFailure()),
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.shareRequested(title: 't'),
        expect: () => [
          MateFlyerState(
            status: MateFlyerStatus.ready,
            flyer: flyer,
            failure: MateFlyerFailure.share,
          ),
        ],
      );

      blocTest<MateFlyerCubit, MateFlyerState>(
        'does nothing without a flyer',
        build: build,
        act: (cubit) => cubit.shareRequested(title: 't'),
        expect: () => <MateFlyerState>[],
      );
    });

    group('retakeRequested', () {
      blocTest<MateFlyerCubit, MateFlyerState>(
        'drops the flyer and the photo',
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.retakeRequested(),
        expect: () => [const MateFlyerState()],
      );

      blocTest<MateFlyerCubit, MateFlyerState>(
        'stays on the web message',
        setUp: () => when(() => repository.canBlurFaces).thenReturn(false),
        build: build,
        act: (cubit) => cubit.retakeRequested(),
        expect: () => <MateFlyerState>[],
      );
    });
  });
}
