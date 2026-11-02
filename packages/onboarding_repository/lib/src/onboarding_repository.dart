import 'dart:math';

import 'package:live_transcript/live_transcript.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:voice_recorder/voice_recorder.dart';

/// {@template onboarding_repository}
/// Onboarding by voice: records the note, and once it's done uploads it to
/// `audio/{uid}/{noteId}.wav`, has `extract` listen to it and
/// `read_transcript` read the words, and says what it understood, step by
/// step.
///
/// With a [LiveTranscriptClient], the words show while the person talks
/// ([liveWords]) and, when the live session saw the note through, the final
/// transcript goes to `read_transcript` instead: no upload, only Spark's
/// step is left. Any trouble with live falls back to the upload, unseen.
///
/// Nothing leaves the phone before `users/{uid}.terms` exists: the terms are
/// read first and a note without them is thrown away (Storage rules, the
/// relay and the callables check the same). The callable deletes the note
/// once read; when it never got to read it, this repository deletes it.
/// {@endtemplate}
class OnboardingRepository {
  /// {@macro onboarding_repository}
  new({
    required this._voiceRecorder,
    required this._rondaApi,
    this._liveTranscript,
    String Function()? newNoteId,
  }) : _newNoteId = newNoteId ?? _randomNoteId;

  final VoiceRecorder _voiceRecorder;
  final RondaApi _rondaApi;
  final LiveTranscriptClient? _liveTranscript;
  final String Function() _newNoteId;

  /// The surface the relay picks Voice Transcribe's words for.
  static const liveSurface = 'signup';

  /// The note being recorded, if any.
  LiveVoiceNote? _note;

  /// The size of a RIFF/WAVE header with no samples after it.
  static const _wavHeaderBytes = 44;

  static String _randomNoteId() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  /// Starts a new voice note for [uid], asking for the microphone the
  /// first time. The words go live once `users/{uid}.terms` is seen.
  ///
  /// Throws a [NoMicrophoneFailure] when there is none to use, a
  /// [MicrophoneDeniedFailure] when it may not be used, and a
  /// [StartVoiceNoteFailure] when the recorder fails.
  Future<void> startVoiceNote(String uid) async {
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
    final note = LiveVoiceNote(
      recorder: _voiceRecorder,
      client: _liveTranscript,
    );
    try {
      await note.start(surface: liveSurface, live: _termsAccepted(uid));
    } on Exception {
      throw const StartVoiceNoteFailure();
    }
    _note = note;
  }

  Future<bool> _termsAccepted(String uid) async {
    try {
      return (await _rondaApi.readUser(uid))?.terms != null;
    } on Exception {
      return false;
    }
  }

  /// How loud the microphone is while a note records, 25 times a second,
  /// from 0 (silence) to 1. Only levels; never the audio.
  Stream<double> voiceLevels() => _voiceRecorder.levels();

  /// What Voice Transcribe has heard so far, revised as the person talks.
  /// Nothing comes without live transcription.
  Stream<String> liveWords() => _note?.words ?? const Stream.empty();

  /// Stops and throws away the note being recorded, if any.
  Future<void> discardVoiceNote() async {
    final note = _note;
    _note = null;
    try {
      await (note?.cancel() ?? _voiceRecorder.cancel());
    } on Exception {
      // Nothing was recording; there is nothing to throw away.
    }
  }

  /// Ends the note: the WAV, and the transcript when live saw it through.
  Future<LiveVoiceNoteResult> _stopNote() async {
    final note = _note;
    _note = null;
    if (note != null) return await note.stop();
    return LiveVoiceNoteResult(
      wav: await _voiceRecorder.stop(),
      transcript: null,
    );
  }

  /// Stops the note and reads what [uid] said in it, one step at a time:
  /// [VoiceNoteUploading], [VoiceNoteListening], [VoiceNoteHeard] with the
  /// words, then [VoiceNoteUnderstood] with the fields, and done. Words
  /// heard live skip straight to [VoiceNoteHeard].
  ///
  /// Each step fails with its own failure, so the person is told what went
  /// wrong: a [RecordVoiceNoteFailure] when the recorder gave back no note,
  /// a [TermsNotAcceptedFailure] before any upload when `users/{uid}.terms`
  /// is missing, an [UploadVoiceNoteFailure] when the note couldn't be sent,
  /// a [VoiceNoteNotUnderstoodFailure] when nothing could be understood, and
  /// a [ReadVoiceNoteFailure] when reading it failed.
  Stream<VoiceNoteReading> readVoiceNote(String uid) async* {
    final LiveVoiceNoteResult note;
    try {
      note = await _stopNote();
    } on Exception {
      throw const RecordVoiceNoteFailure();
    }
    final wav = note.wav;
    // A WAV header alone (44 bytes) is a note with no sound in it.
    if (wav == null || wav.length <= _wavHeaderBytes) {
      throw const RecordVoiceNoteFailure();
    }
    if (note.transcript case final heard?) {
      yield VoiceNoteHeard(heard);
      if (await _readTranscript(heard) case final signup?) {
        yield VoiceNoteUnderstood(signup);
        return;
      }
    }

    yield const VoiceNoteUploading();
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

    yield const VoiceNoteListening();
    final String transcript;
    try {
      transcript = await _rondaApi.listenToVoiceNote(path);
    } on UnreadableVoiceNoteException {
      throw const VoiceNoteNotUnderstoodFailure();
    } on Exception {
      await _deleteUnread(path);
      throw const ReadVoiceNoteFailure();
    }

    // The note is gone now: only the words are left.
    yield VoiceNoteHeard(transcript);
    final ExtractedFields fields;
    try {
      fields = await _rondaApi.readTranscript(transcript);
    } on UnreadableVoiceNoteException {
      throw const VoiceNoteNotUnderstoodFailure();
    } on Exception {
      throw const ReadVoiceNoteFailure();
    }
    yield VoiceNoteUnderstood(_signup(fields));
  }

  /// What `read_transcript` understood of the words heard live, or `null`
  /// when the call failed and the WAV should be read the usual way.
  ///
  /// Throws a [VoiceNoteNotUnderstoodFailure] when nothing came of them.
  Future<VoiceSignup?> _readTranscript(String transcript) async {
    final ExtractedFields fields;
    try {
      fields = await _rondaApi.readTranscript(transcript);
    } on UnreadableVoiceNoteException {
      throw const VoiceNoteNotUnderstoodFailure();
    } on Exception {
      return null;
    }
    return _signup(fields);
  }

  VoiceSignup _signup(ExtractedFields fields) {
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
