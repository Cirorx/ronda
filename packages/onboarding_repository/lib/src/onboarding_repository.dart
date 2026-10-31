import 'dart:math';
import 'dart:typed_data';

import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:voice_recorder/voice_recorder.dart';

/// {@template onboarding_repository}
/// Onboarding by voice: records the note, and once it's done uploads it to
/// `audio/{uid}/{noteId}.wav`, awaits the `extract` callable and returns
/// what it understood.
///
/// Nothing leaves the phone before `users/{uid}.terms` exists: the terms are
/// read first and a note without them is thrown away (Storage rules and the
/// callable check the same). The callable deletes the note once read; when
/// it never got to read it, this repository deletes it.
/// {@endtemplate}
class OnboardingRepository {
  /// {@macro onboarding_repository}
  new({
    required this._voiceRecorder,
    required this._rondaApi,
    String Function()? newNoteId,
  }) : _newNoteId = newNoteId ?? _randomNoteId;

  final VoiceRecorder _voiceRecorder;
  final RondaApi _rondaApi;
  final String Function() _newNoteId;

  /// The size of a RIFF/WAVE header with no samples after it.
  static const _wavHeaderBytes = 44;

  static String _randomNoteId() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  /// Starts a new voice note, asking for the microphone the first time.
  ///
  /// Throws a [NoMicrophoneFailure] when there is none to use, a
  /// [MicrophoneDeniedFailure] when it may not be used, and a
  /// [StartVoiceNoteFailure] when the recorder fails.
  Future<void> startVoiceNote() async {
    final bool allowed;
    final bool present;
    try {
      allowed = await _voiceRecorder.hasPermission();
      // A browser with no microphone answers like one that was refused.
      present = allowed || await _voiceRecorder.hasMicrophone();
    } on Exception {
      throw const StartVoiceNoteFailure();
    }
    if (!present) throw const NoMicrophoneFailure();
    if (!allowed) throw const MicrophoneDeniedFailure();
    try {
      await _voiceRecorder.start();
    } on Exception {
      throw const StartVoiceNoteFailure();
    }
  }

  /// How loud the microphone is while a note records, 25 times a second,
  /// from 0 (silence) to 1. Only levels; never the audio.
  Stream<double> voiceLevels() => _voiceRecorder.levels();

  /// Stops and throws away the note being recorded, if any.
  Future<void> discardVoiceNote() async {
    try {
      await _voiceRecorder.cancel();
    } on Exception {
      // Nothing was recording; there is nothing to throw away.
    }
  }

  /// Stops the note and returns what [uid] said in it.
  ///
  /// Each step fails with its own failure, so the person is told what went
  /// wrong: a [RecordVoiceNoteFailure] when the recorder gave back no note,
  /// a [TermsNotAcceptedFailure] before any upload when `users/{uid}.terms`
  /// is missing, an [UploadVoiceNoteFailure] when the note couldn't be sent,
  /// a [VoiceNoteNotUnderstoodFailure] when nothing could be understood, and
  /// a [ReadVoiceNoteFailure] when reading it failed.
  Future<VoiceSignup> readVoiceNote(String uid) async {
    final Uint8List? wav;
    try {
      wav = await _voiceRecorder.stop();
    } on Exception {
      throw const RecordVoiceNoteFailure();
    }
    // A WAV header alone (44 bytes) is a note with no sound in it.
    if (wav == null || wav.length <= _wavHeaderBytes) {
      throw const RecordVoiceNoteFailure();
    }

    final UserDocument? user;
    try {
      user = await _rondaApi.readUser(uid);
    } on Exception {
      throw const UploadVoiceNoteFailure(code: 'read-user');
    }
    if (user?.terms == null) throw const TermsNotAcceptedFailure();

    final String path;
    try {
      path = await _rondaApi.uploadVoiceNote(
        uid: uid,
        noteId: _newNoteId(),
        wav: wav,
      );
    } on VoiceNoteRefusedException catch (error) {
      throw UploadVoiceNoteFailure(refused: true, code: error.code);
    } on VoiceNoteUploadException catch (error) {
      throw UploadVoiceNoteFailure(code: error.code);
    } on Exception {
      throw const UploadVoiceNoteFailure();
    }

    final ExtractedFields fields;
    try {
      fields = await _rondaApi.extract(path);
    } on UnreadableVoiceNoteException {
      throw const VoiceNoteNotUnderstoodFailure();
    } on Exception {
      await _deleteUnread(path);
      throw const ReadVoiceNoteFailure();
    }
    final signup = VoiceSignup(
      firstName: fields.firstName,
      ageBand: fields.ageBand,
      barrio: fields.barrio,
      pretexts: fields.pretexts,
      slots: fields.slots,
      brings: fields.brings,
    );
    if (signup.isEmpty) throw const VoiceNoteNotUnderstoodFailure();
    return signup;
  }

  /// Deletes a note the callable may not have reached. A note it did read is
  /// already gone, so a failure here is expected and the 1-day lifecycle
  /// rule is the backstop.
  Future<void> _deleteUnread(String path) async {
    try {
      await _rondaApi.deleteVoiceNote(path);
    } on Exception {
      // Already deleted, or unreachable: the lifecycle rule removes it.
    }
  }
}
