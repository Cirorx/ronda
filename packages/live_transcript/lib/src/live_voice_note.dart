import 'dart:async';
import 'dart:typed_data';

import 'package:live_transcript/src/live_transcript_client.dart';
import 'package:voice_recorder/voice_recorder.dart';

/// {@template live_voice_note_result}
/// What a [LiveVoiceNote] came to: the note as a WAV for the upload path,
/// and the final transcript when the live session saw it through.
/// {@endtemplate}
class const LiveVoiceNoteResult({
  /// The whole note, 16 kHz mono 16-bit WAV; `null` when nothing recorded.
  required final Uint8List? wav,

  /// What Voice Transcribe heard, live; `null` when live wasn't on or
  /// failed at any point, so the note must be read the usual way.
  required final String? transcript,
}) {
  /// {@macro live_voice_note_result}
  this;
}

/// {@template live_voice_note}
/// One voice note, recorded with the samples in hand: they feed the live
/// transcription when it is on, and the WAV for the upload path either
/// way. Live is best effort: if the session can't open, drops, or is slow,
/// the note goes on and [stop] answers with no transcript, so the caller
/// reads the WAV as it always did. The person notices nothing but the wait.
/// {@endtemplate}
class LiveVoiceNote {
  /// {@macro live_voice_note}
  new({
    required this._recorder,
    this._client,
    this.maxBuffered = const Duration(seconds: 4),
  });

  final VoiceRecorder _recorder;
  final LiveTranscriptClient? _client;

  /// How much audio may wait for the relay's `ready` before live is given
  /// up for this note: Meta refuses audio more than 5 s ahead.
  final Duration maxBuffered;

  /// Bytes per second of 16 kHz mono 16-bit PCM.
  static const int bytesPerSecond = VoiceRecorder.sampleRate * 2;

  final _words = StreamController<String>.broadcast();
  StreamSubscription<Uint8List>? _chunks;
  StreamSubscription<String>? _sessionWords;
  LiveTranscription? _session;
  Future<void>? _opening;
  BytesBuilder? _buffered;
  bool _live = false;

  /// The transcript so far, revised as the person talks. Nothing comes
  /// when live is off or failed.
  Stream<String> get words => _words.stream;

  /// How loud the microphone is, 25 times a second, from 0 to 1.
  Stream<double> levels() => _recorder.levels();

  /// Starts recording at once and, once [live] says so (the terms are
  /// accepted; `false` or an error means no), opens the transcription
  /// session for [surface] (`signup`, `line` or `plan`) and streams the
  /// samples to it, the first ones buffered until the relay is ready.
  ///
  /// Throws what the recorder throws when it can't start; a session that
  /// can't open only turns live off.
  Future<void> start({
    required String surface,
    required Future<bool> live,
  }) async {
    _live = _client != null;
    if (_live) {
      _buffered = BytesBuilder(copy: false);
      // Called before the recorder starts, so [live] is listened to at once.
      _opening = _open(surface, live);
    }
    final Stream<Uint8List> chunks;
    try {
      chunks = await _recorder.startStreaming();
    } on Object {
      _giveUp();
      await _opening;
      await _session?.abandon();
      await _end();
      rethrow;
    }
    _chunks = chunks.listen(_onChunk, onError: (Object _) {});
  }

  Future<void> _open(String surface, Future<bool> live) async {
    try {
      final allowed = await live;
      if (!allowed || !_live) return _giveUp();
      final session = await _client!.start(surface);
      if (!_live) {
        await session.abandon();
        return;
      }
      _session = session;
      _sessionWords = session.words.listen(_words.add);
      if (_buffered?.takeBytes() case final pending? when pending.isNotEmpty) {
        session.add(pending);
      }
      _buffered = null;
    } on Exception {
      _giveUp();
    }
  }

  void _onChunk(Uint8List chunk) {
    if (!_live) return;
    if (_session case final session?) return session.add(chunk);
    final buffered = _buffered;
    if (buffered == null) return;
    buffered.add(chunk);
    if (buffered.length > maxBuffered.inMilliseconds * bytesPerSecond / 1000) {
      _giveUp();
    }
  }

  /// Live is over for this note: the samples keep recording for the WAV.
  void _giveUp() {
    _live = false;
    _buffered = null;
  }

  /// Stops recording and answers with the WAV and, when live saw the note
  /// through, the final transcript.
  Future<LiveVoiceNoteResult> stop() async {
    final wav = await _recorder.stop();
    await _chunks?.cancel();
    _chunks = null;
    await _opening;
    final transcript = _live ? await _session?.finish() : null;
    await _end();
    final text = transcript?.trim();
    return LiveVoiceNoteResult(
      wav: wav,
      transcript: text == null || text.isEmpty ? null : text,
    );
  }

  /// Throws the note away, live session included.
  Future<void> cancel() async {
    await _recorder.cancel();
    await _chunks?.cancel();
    _chunks = null;
    _giveUp();
    await _opening;
    await _session?.abandon();
    await _end();
  }

  Future<void> _end() async {
    _live = false;
    await _sessionWords?.cancel();
    _sessionWords = null;
    _session = null;
    _opening = null;
    await _words.close();
  }
}
