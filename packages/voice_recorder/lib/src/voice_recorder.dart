import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:voice_recorder/src/microphones/microphones.dart' as microphones;

/// {@template voice_recorder_exception}
/// The recorder failed. On web, `record` lets the browser's own error out
/// (a `getUserMedia` refusal, a microphone in use, an audio worklet that
/// won't load), which is not a Dart [Exception]; [VoiceRecorder] turns
/// whatever its calls throw into this, so callers' `on Exception` sees it.
/// It carries no detail, like the rest of this package's output.
/// {@endtemplate}
class VoiceRecorderException implements Exception {
  /// {@macro voice_recorder_exception}
  const new();
}

/// {@template voice_recorder}
/// Records one voice note at a time as the WAV Voice Transcribe takes:
/// RIFF/WAVE, 16 kHz, mono, 16-bit PCM, with no gain, echo or noise
/// processing on the phone.
///
/// On a phone the note is a file in the temporary directory, read and then
/// deleted by [stop]; on web `record` keeps it in memory and [stop] reads it
/// from the blob URL. The bytes never touch disk beyond that. It logs
/// nothing.
/// {@endtemplate}
class VoiceRecorder {
  /// {@macro voice_recorder}
  new({
    AudioRecorder? recorder,
    Future<String> Function()? temporaryDirectory,
    Future<Uint8List> Function(String path)? readBytes,
    Future<void> Function(String path)? deleteFile,
    Future<bool> Function()? hasMicrophone,
    this._isWeb = kIsWeb,
  }) : _recorder = recorder ?? AudioRecorder(),
       _temporaryDirectory = temporaryDirectory ?? _systemTemporaryDirectory,
       _readBytes = readBytes ?? _readXFile,
       _deleteFile = deleteFile ?? _deleteIoFile,
       _hasMicrophone = hasMicrophone ?? microphones.hasMicrophone;

  final AudioRecorder _recorder;
  final Future<String> Function() _temporaryDirectory;
  final Future<Uint8List> Function(String path) _readBytes;
  final Future<void> Function(String path) _deleteFile;
  final Future<bool> Function() _hasMicrophone;
  final bool _isWeb;

  /// The samples of the note being streamed, so far; `null` unless
  /// [startStreaming] is recording.
  BytesBuilder? _samples;
  StreamSubscription<Uint8List>? _streaming;
  StreamController<Uint8List>? _chunks;
  StreamController<double>? _streamedLevels;

  /// Samples of the current 40 ms window, for [levels] while streaming.
  int _windowSamples = 0;
  int _windowPeak = 0;

  /// How every note is recorded (`record` defaults to AAC 44.1 kHz stereo).
  static const config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  );

  /// How every note is recorded when its samples are wanted as they come
  /// ([startStreaming]): the same sound, as raw 16-bit PCM.
  static const streamConfig = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000,
    numChannels: 1,
  );

  /// The sample rate of every note, in Hz.
  static const int sampleRate = 16000;

  /// How often [levels] reads the microphone: 25 times a second.
  static const levelInterval = Duration(milliseconds: 40);

  /// How many samples [levels] measures at a time while streaming: 40 ms.
  static const int samplesPerLevel = sampleRate * 40 ~/ 1000;

  /// The size of a RIFF/WAVE header with no samples after it.
  static const wavHeaderBytes = 44;

  /// The quietest level [levelOf] tells apart from silence, in dBFS.
  static const quietestDb = -60.0;

  /// A level from 0 (silence, or no sound at all) to 1 (full scale), from
  /// dBFS as `record` reads it. Quieter than [quietestDb] is 0; a dead
  /// microphone on web reads negative infinity, also 0.
  static double levelOf(double dbfs) {
    if (!dbfs.isFinite || dbfs <= quietestDb) return 0;
    if (dbfs >= 0) return 1;
    return 1 - dbfs / quietestDb;
  }

  /// The note's file name; on web `record` ignores it.
  static const fileName = 'voice_note.wav';

  static Future<String> _systemTemporaryDirectory() async =>
      (await getTemporaryDirectory()).path;

  static Future<Uint8List> _readXFile(String path) => XFile(path).readAsBytes();

  static Future<void> _deleteIoFile(String path) => File(path).delete();

  /// Runs [call], keeping an [Exception] as it is and turning any other
  /// error into a [VoiceRecorderException], with its stack trace.
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on Exception {
      rethrow;
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(const VoiceRecorderException(), stackTrace);
    }
  }

  /// Whether the microphone may be used, asking the person the first time.
  Future<bool> hasPermission() => _guard(_recorder.hasPermission);

  /// Whether there is any microphone to ask for: a browser on a computer
  /// may have none.
  Future<bool> hasMicrophone() => _hasMicrophone();

  /// A RIFF/WAVE file holding [pcm]: 16 kHz, mono, 16-bit, as [config]
  /// records.
  static Uint8List wavOf(Uint8List pcm) {
    const bytesPerSample = 2;
    final header = ByteData(wavHeaderBytes);
    void ascii(int offset, String tag) {
      for (var i = 0; i < 4; i++) {
        header.setUint8(offset + i, tag.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header
      ..setUint32(16, 16, Endian.little) // PCM format chunk size
      ..setUint16(20, 1, Endian.little) // PCM
      ..setUint16(22, 1, Endian.little) // channels
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, sampleRate * bytesPerSample, Endian.little)
      ..setUint16(32, bytesPerSample, Endian.little)
      ..setUint16(34, 16, Endian.little); // bits per sample
    ascii(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
  }

  /// How loud the microphone is while a note records, every
  /// [levelInterval], from 0 to 1 ([levelOf]). Only levels; never the audio.
  /// While [startStreaming] records, the levels are measured from the
  /// samples themselves, 40 ms at a time.
  Stream<double> levels() {
    if (_streamedLevels case final streamed?) return streamed.stream;
    return _recorder
        .onAmplitudeChanged(levelInterval)
        .map((amplitude) => levelOf(amplitude.current));
  }

  /// Starts a new note and hands back its samples as they are recorded:
  /// raw 16 kHz mono 16-bit PCM, in chunks, as [streamConfig] says. [stop]
  /// still returns the whole note as a WAV, built from the same samples.
  ///
  /// Throws a [VoiceRecorderException] for any error that is not an
  /// [Exception] already.
  Future<Stream<Uint8List>> startStreaming() => _guard(() async {
    final source = await _recorder.startStream(streamConfig);
    final samples = BytesBuilder(copy: false);
    final levels = StreamController<double>.broadcast();
    final chunks = StreamController<Uint8List>.broadcast();
    _samples = samples;
    _chunks = chunks;
    _streamedLevels = levels;
    _windowSamples = 0;
    _windowPeak = 0;
    _streaming = source.listen(
      (chunk) {
        samples.add(chunk);
        _measure(chunk, levels);
        chunks.add(chunk);
      },
      onError: chunks.addError,
      onDone: () {
        unawaited(chunks.close());
        unawaited(levels.close());
      },
    );
    return chunks.stream;
  });

  /// Feeds [levels] a level for each [samplesPerLevel] samples of [chunk]
  /// (the peak of the window, in dBFS, through [levelOf]).
  void _measure(Uint8List chunk, StreamController<double> levels) {
    final samples = chunk.buffer.asByteData(
      chunk.offsetInBytes,
      chunk.lengthInBytes - chunk.lengthInBytes % 2,
    );
    for (var i = 0; i < samples.lengthInBytes; i += 2) {
      _windowPeak = math.max(
        _windowPeak,
        samples.getInt16(i, Endian.little).abs(),
      );
      if (++_windowSamples < samplesPerLevel) continue;
      final dbfs = _windowPeak == 0
          ? double.negativeInfinity
          : 20 * math.log(_windowPeak / 32767) / math.ln10;
      levels.add(levelOf(dbfs));
      _windowSamples = 0;
      _windowPeak = 0;
    }
  }

  /// Ends a streamed note and returns its samples, or `null` when none was
  /// streaming.
  Future<Uint8List?> _endStreaming() async {
    final samples = _samples;
    if (samples == null) return null;
    await _streaming?.cancel();
    await _chunks?.close();
    await _streamedLevels?.close();
    _samples = null;
    _streaming = null;
    _chunks = null;
    _streamedLevels = null;
    return samples.takeBytes();
  }

  /// Starts a new note.
  ///
  /// Throws a [VoiceRecorderException] for any error that is not an
  /// [Exception] already, as every call here does.
  Future<void> start() => _guard(() async {
    final path = _isWeb ? fileName : '${await _temporaryDirectory()}/$fileName';
    await _recorder.start(config, path: path);
  });

  /// Stops the note and returns its WAV bytes, or `null` when nothing was
  /// recording. On a phone the file is deleted once read; a streamed note
  /// ([startStreaming]) is built from its samples.
  Future<Uint8List?> stop() => _guard(() async {
    final path = await _recorder.stop();
    if (await _endStreaming() case final pcm?) return wavOf(pcm);
    if (path == null) return null;
    try {
      return await _readBytes(path);
    } finally {
      if (!_isWeb) await _deleteFile(path);
    }
  });

  /// Stops and throws the note away.
  Future<void> cancel() => _guard(() async {
    await _recorder.cancel();
    await _endStreaming();
  });

  /// Releases the microphone for good.
  Future<void> dispose() => _guard(_recorder.dispose);
}
