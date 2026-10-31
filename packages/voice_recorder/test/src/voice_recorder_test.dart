import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:voice_recorder/voice_recorder.dart';

class _MockAudioRecorder extends Mock implements AudioRecorder;

class _FakePathProvider(final String _directory)
    extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => _directory;
}

void main() {
  group(VoiceRecorder, () {
    late AudioRecorder recorder;
    late List<String> read;
    late List<String> deleted;

    final wav = Uint8List.fromList([82, 73, 70, 70]);

    setUpAll(() {
      registerFallbackValue(const RecordConfig());
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      recorder = _MockAudioRecorder();
      read = [];
      deleted = [];
      when(() => recorder.start(any(), path: any(named: 'path')))
          .thenAnswer((_) async {});
    });

    VoiceRecorder subject({bool isWeb = false}) => VoiceRecorder(
      recorder: recorder,
      temporaryDirectory: () async => '/tmp/app',
      readBytes: (path) async {
        read.add(path);
        return wav;
      },
      deleteFile: (path) async => deleted.add(path),
      isWeb: isWeb,
    );

    test('builds the real plugin by default', () {
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.llfbandit.record/messages'),
            (_) async => null,
          );

      expect(VoiceRecorder(), isA<VoiceRecorder>());
    });

    test('records WAV, 16 kHz, mono, with no processing', () {
      expect(VoiceRecorder.config.encoder, equals(AudioEncoder.wav));
      expect(VoiceRecorder.config.sampleRate, equals(16000));
      expect(VoiceRecorder.config.numChannels, equals(1));
      expect(VoiceRecorder.config.autoGain, isFalse);
      expect(VoiceRecorder.config.echoCancel, isFalse);
      expect(VoiceRecorder.config.noiseSuppress, isFalse);
    });

    test('reads and deletes a real file in the temporary directory by '
        'default', () async {
      final directory = Directory.systemTemp.createTempSync('voice');
      addTearDown(() => directory.deleteSync(recursive: true));
      PathProviderPlatform.instance = _FakePathProvider(directory.path);
      final file = File('${directory.path}/${VoiceRecorder.fileName}');
      when(() => recorder.start(any(), path: any(named: 'path')))
          .thenAnswer((invocation) async => file.writeAsBytesSync(wav));
      when(() => recorder.stop()).thenAnswer((_) async => file.path);
      final defaults = VoiceRecorder(recorder: recorder, isWeb: false);

      await defaults.start();

      verify(() => recorder.start(VoiceRecorder.config, path: file.path))
          .called(1);
      expect(await defaults.stop(), equals(wav));
      expect(file.existsSync(), isFalse);
    });

    group('hasMicrophone', () {
      test('is true on a phone by default', () async {
        expect(await VoiceRecorder(recorder: recorder).hasMicrophone(), isTrue);
      });

      test('asks the injected check', () async {
        final none = VoiceRecorder(
          recorder: recorder,
          hasMicrophone: () async => false,
        );

        expect(await none.hasMicrophone(), isFalse);
      });
    });

    group('levelOf', () {
      test('is 0 at or below the quietest level', () {
        expect(VoiceRecorder.levelOf(-160), equals(0));
        expect(VoiceRecorder.levelOf(VoiceRecorder.quietestDb), equals(0));
      });

      test('is 0 for a dead microphone on web', () {
        expect(VoiceRecorder.levelOf(double.negativeInfinity), equals(0));
        expect(VoiceRecorder.levelOf(double.nan), equals(0));
      });

      test('rises with the voice up to 1 at full scale', () {
        expect(VoiceRecorder.levelOf(-30), closeTo(0.5, 1e-9));
        expect(VoiceRecorder.levelOf(0), equals(1));
        expect(VoiceRecorder.levelOf(3), equals(1));
      });
    });

    test('levels reads the amplitude every 40 ms, as 0 to 1', () async {
      when(() => recorder.onAmplitudeChanged(any())).thenAnswer(
        (_) => Stream.fromIterable([
          Amplitude(current: -160, max: -160),
          Amplitude(current: -30, max: -30),
          Amplitude(current: 0, max: 0),
        ]),
      );

      expect(await subject().levels().toList(), equals([0, 0.5, 1]));
      verify(
        () => recorder.onAmplitudeChanged(const Duration(milliseconds: 40)),
      ).called(1);
    });

    test('hasPermission asks the recorder', () async {
      when(() => recorder.hasPermission()).thenAnswer((_) async => true);

      expect(await subject().hasPermission(), isTrue);
    });

    group('start', () {
      test('records into the temporary directory on a phone', () async {
        await subject().start();

        verify(
          () => recorder.start(
            VoiceRecorder.config,
            path: '/tmp/app/voice_note.wav',
          ),
        ).called(1);
      });

      test('passes only the file name on web', () async {
        await subject(isWeb: true).start();

        verify(
          () => recorder.start(VoiceRecorder.config, path: 'voice_note.wav'),
        ).called(1);
      });
    });

    group('stop', () {
      test('returns the bytes and deletes the file on a phone', () async {
        const path = '/tmp/app/voice_note.wav';
        when(() => recorder.stop()).thenAnswer((_) async => path);

        expect(await subject().stop(), equals(wav));
        expect(read, equals([path]));
        expect(deleted, equals([path]));
      });

      test('deletes the file even when reading it fails', () async {
        const path = '/tmp/app/voice_note.wav';
        when(() => recorder.stop()).thenAnswer((_) async => path);
        final failing = VoiceRecorder(
          recorder: recorder,
          readBytes: (_) async => throw Exception('unreadable'),
          deleteFile: (path) async => deleted.add(path),
          isWeb: false,
        );

        await expectLater(failing.stop(), throwsException);
        expect(deleted, equals([path]));
      });

      test('reads the blob URL and deletes nothing on web', () async {
        const url = 'blob:http://localhost/abc';
        when(() => recorder.stop()).thenAnswer((_) async => url);

        expect(await subject(isWeb: true).stop(), equals(wav));
        expect(read, equals([url]));
        expect(deleted, isEmpty);
      });

      test('returns null when nothing was recording', () async {
        when(() => recorder.stop()).thenAnswer((_) async => null);

        expect(await subject().stop(), isNull);
        expect(read, isEmpty);
      });
    });

    test('cancel throws the note away', () async {
      when(() => recorder.cancel()).thenAnswer((_) async {});

      await subject().cancel();

      verify(() => recorder.cancel()).called(1);
    });

    test('dispose releases the recorder', () async {
      when(() => recorder.dispose()).thenAnswer((_) async {});

      await subject().dispose();

      verify(() => recorder.dispose()).called(1);
    });
  });
}
