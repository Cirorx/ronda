import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

/// {@template live_transcript_exception}
/// The relay couldn't take the note: no signed-in member, no connection, a
/// handshake it refused, or an answer that wasn't the one expected. It
/// carries no detail, like everything else that leaves this package: the
/// note goes on without live words and is read the usual way at the end.
/// {@endtemplate}
class LiveTranscriptException implements Exception {
  /// {@macro live_transcript_exception}
  const new();

  @override
  String toString() => 'LiveTranscriptException';
}

/// {@template live_transcript_client}
/// Opens a transcription session with Ronda's relay, which holds the Meta
/// key and sits in front of Voice Transcribe's realtime mode
/// (`wss://api.meta.ai/v1/asr/realtime`). The phone never talks to Meta.
///
/// The wire, between the phone and the relay:
/// 1. the phone sends one JSON text frame, `{"idToken", "surface"}`, with
///    the member's Firebase ID token; the relay checks it and the terms,
///    opens the session with Meta and answers `{"type": "ready"}`, or
///    `{"type": "error"}` and closes;
/// 2. the phone sends raw 16 kHz mono 16-bit PCM as binary frames, paced as
///    it records them;
/// 3. the relay forwards `{"type": "transcript", "transcript", "final"}`
///    as Meta emits it, each partial the whole text so far;
/// 4. the phone sends `{"type": "endStream"}`; the final transcript comes
///    back and the relay closes with 1000.
///
/// Nothing is stored on either side and this client logs nothing.
/// {@endtemplate}
class LiveTranscriptClient {
  /// {@macro live_transcript_client}
  new({
    required this._url,
    required this._idToken,
    WebSocketChannel Function(Uri url)? connect,
    this.readyTimeout = const Duration(seconds: 4),
    this.finalTimeout = const Duration(seconds: 6),
  }) : _connect = connect ?? WebSocketChannel.connect;

  final Uri _url;
  final Future<String?> Function() _idToken;
  final WebSocketChannel Function(Uri url) _connect;

  /// How long connecting and the relay's `ready` may take, together.
  final Duration readyTimeout;

  /// How long the final transcript may take after `endStream`.
  final Duration finalTimeout;

  /// Opens a session for one note recorded on [surface] (`signup`, `line`
  /// or `plan`: it picks the words Voice Transcribe expects).
  ///
  /// Throws a [LiveTranscriptException] when the session can't open within
  /// [readyTimeout], for any reason.
  Future<LiveTranscription> start(String surface) async {
    final String token;
    try {
      token = await _idToken() ?? (throw const LiveTranscriptException());
    } on Exception {
      throw const LiveTranscriptException();
    }
    final WebSocketChannel channel;
    try {
      channel = _connect(_url);
    } on Object {
      throw const LiveTranscriptException();
    }
    final session = LiveTranscription._(channel, finalTimeout: finalTimeout);
    try {
      await channel.ready.timeout(readyTimeout);
      channel.sink.add(jsonEncode({'idToken': token, 'surface': surface}));
      await session._ready.future.timeout(readyTimeout);
    } on Object {
      await session.abandon();
      throw const LiveTranscriptException();
    }
    return session;
  }
}

/// One note's transcription session with the relay: samples go in with
/// [add], the words come out of [words] as they are recognised, and
/// [finish] waits for the final transcript.
class LiveTranscription {
  new _(this._channel, {required this._finalTimeout}) {
    _subscription = _channel.stream.listen(
      _onMessage,
      onError: (Object _) => _fail(),
      onDone: _fail,
    );
  }

  final WebSocketChannel _channel;
  final Duration _finalTimeout;
  late final StreamSubscription<dynamic> _subscription;
  final _ready = Completer<void>();
  final _finished = Completer<String?>();
  final _words = StreamController<String>.broadcast();
  bool _ended = false;
  Future<void>? _closing;

  /// The whole transcript so far, each time Voice Transcribe revises it.
  /// Closed once the session is over.
  Stream<String> get words => _words.stream;

  /// Whether the session is over, finished or failed.
  bool get isOver => _finished.isCompleted;

  void _onMessage(dynamic message) {
    if (message is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(message);
    } on FormatException {
      return _fail();
    }
    switch (decoded) {
      case {'type': 'ready'}:
        if (!_ready.isCompleted) _ready.complete();
      case {'type': 'transcript', 'transcript': final String text}:
        _words.add(text);
        if (decoded['final'] == true) _finish(text);
      case {'type': 'error'}:
        _fail();
      default:
        // Unknown events are ignored, so the relay can add some.
        break;
    }
  }

  void _finish(String text) {
    if (_finished.isCompleted) return;
    _finished.complete(text);
    _closing = _close();
  }

  void _fail() {
    if (!_ready.isCompleted) {
      _ready.completeError(const LiveTranscriptException());
    }
    if (_finished.isCompleted) return;
    _finished.complete(null);
    _closing = _close();
  }

  Future<void> _close() async {
    await _subscription.cancel();
    await _words.close();
    try {
      await _channel.sink.close();
    } on Object {
      // Already closed by the relay.
    }
  }

  /// Sends the next samples: raw 16 kHz mono 16-bit PCM. Dropped once the
  /// note ended or the session failed.
  void add(Uint8List pcm) {
    if (_ended || isOver) return;
    _channel.sink.add(pcm);
  }

  /// Ends the note and returns the final transcript, or `null` when the
  /// session failed or the transcript didn't come within the client's
  /// `finalTimeout`. The session is closed either way.
  Future<String?> finish() async {
    if (!_ended && !isOver) {
      _ended = true;
      _channel.sink.add(jsonEncode({'type': 'endStream'}));
    }
    String? transcript;
    try {
      transcript = await _finished.future.timeout(_finalTimeout);
    } on TimeoutException {
      _fail();
    }
    await _closing;
    return transcript;
  }

  /// Drops the session without waiting for anything.
  Future<void> abandon() async {
    _ended = true;
    _ready.future.ignore();
    _fail();
    await _closing;
  }
}
