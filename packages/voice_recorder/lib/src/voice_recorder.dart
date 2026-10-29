import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
    this._isWeb = kIsWeb,
  }) : _recorder = recorder ?? AudioRecorder(),
       _temporaryDirectory = temporaryDirectory ?? _systemTemporaryDirectory,
       _readBytes = readBytes ?? _readXFile,
       _deleteFile = deleteFile ?? _deleteIoFile;

  final AudioRecorder _recorder;
  final Future<String> Function() _temporaryDirectory;
  final Future<Uint8List> Function(String path) _readBytes;
  final Future<void> Function(String path) _deleteFile;
  final bool _isWeb;

  /// How every note is recorded (`record` defaults to AAC 44.1 kHz stereo).
  static const config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  );

  /// The note's file name; on web `record` ignores it.
  static const fileName = 'voice_note.wav';

  static Future<String> _systemTemporaryDirectory() async =>
      (await getTemporaryDirectory()).path;

  static Future<Uint8List> _readXFile(String path) => XFile(path).readAsBytes();

  static Future<void> _deleteIoFile(String path) => File(path).delete();

  /// Whether the microphone may be used, asking the person the first time.
  Future<bool> hasPermission() => _recorder.hasPermission();

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
