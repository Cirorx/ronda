import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:voice_recorder/src/microphones/microphones.dart' as microphones;

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

  /// How every note is recorded (`record` defaults to AAC 44.1 kHz stereo).
  static const config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  );

  /// How often [levels] reads the microphone: 25 times a second.
  static const levelInterval = Duration(milliseconds: 40);

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

  /// Whether the microphone may be used, asking the person the first time.
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Whether there is any microphone to ask for: a browser on a computer
  /// may have none.
  Future<bool> hasMicrophone() => _hasMicrophone();

  /// How loud the microphone is while a note records, every
  /// [levelInterval], from 0 to 1 ([levelOf]). Only levels; never the audio.
  Stream<double> levels() => _recorder
      .onAmplitudeChanged(levelInterval)
      .map((amplitude) => levelOf(amplitude.current));

  /// Starts a new note.
  Future<void> start() async {
    final path = _isWeb ? fileName : '${await _temporaryDirectory()}/$fileName';
    await _recorder.start(config, path: path);
  }

  /// Stops the note and returns its WAV bytes, or `null` when nothing was
  /// recording. On a phone the file is deleted once read.
  Future<Uint8List?> stop() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    try {
      return await _readBytes(path);
    } finally {
      if (!_isWeb) await _deleteFile(path);
    }
  }

  /// Stops and throws the note away.
  Future<void> cancel() => _recorder.cancel();

  /// Releases the microphone for good.
  Future<void> dispose() => _recorder.dispose();
}
