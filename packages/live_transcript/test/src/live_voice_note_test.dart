import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_transcript/live_transcript.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voice_recorder/voice_recorder.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _MockVoiceRecorder extends Mock implements VoiceRecorder;

class _MockWebSocketChannel extends Mock implements WebSocketChannel;

class _MockWebSocketSink extends Mock implements WebSocketSink;

void main() {
  group(LiveVoiceNote, () {
    late VoiceRecorder recorder;
    late StreamController<Uint8List> chunks;
    late WebSocketChannel channel;
    late WebSocketSink sink;
    late StreamController<dynamic> fromRelay;
    late List<Object?> sent;
    late Completer<void> ready;

    final wav = Uint8List.fromList([82, 73, 70, 70]);
    final one = Uint8List.fromList([1, 1]);
    final two = Uint8List.fromList([2, 2]);

    String frame(Map<String, Object?> event) => jsonEncode(event);
    String transcript(String text, {bool isFinal = false}) =>
        frame({'type': 'transcript', 'transcript': text, 'final': isFinal});

    setUp(() {
      recorder = _MockVoiceRecorder();
      chunks = StreamController<Uint8List>();
      channel = _MockWebSocketChannel();
      sink = _MockWebSocketSink();
      fromRelay = StreamController<dynamic>();
      sent = [];
      ready = Completer<void>();
      when(() => recorder.startStreaming())
          .thenAnswer((_) async => chunks.stream);
      when(() => recorder.stop()).thenAnswer((_) async {
        await chunks.close();
        return wav;
      });
      when(() => recorder.cancel()).thenAnswer((_) => chunks.close());
      when(() => recorder.levels()).thenAnswer((_) => Stream.value(0.5));
      when(() => channel.ready).thenAnswer((_) => ready.future);
      when(() => channel.stream).thenAnswer((_) => fromRelay.stream);
      when(() => channel.sink).thenReturn(sink);
      when(() => sink.add(any<Object?>())).thenAnswer(
        (invocation) => sent.add(invocation.positionalArguments.single),
      );
      when(() => sink.close()).thenAnswer((_) async {});
    });

    LiveTranscriptClient client({
      Duration timeout = const Duration(milliseconds: 50),
    }) => LiveTranscriptClient(
      url: Uri.parse('wss://relay.example/v1/live'),
      idToken: () async => 'id-token',
      connect: (_) => channel,
      readyTimeout: timeout,
      finalTimeout: timeout,
    );

    LiveVoiceNote subject({
      bool withClient = true,
      Duration maxBuffered = const Duration(seconds: 4),
    }) => LiveVoiceNote(
      recorder: recorder,
      client: withClient ? client() : null,
      maxBuffered: maxBuffered,
    );

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    group('start', () {
      test(
        'records in streaming mode and, with no client, streams nothing',
        () async {
          final note = subject(withClient: false);

          await note.start(surface: 'signup', live: Future.value(true));
          chunks.add(one);
          await settle();

          verify(() => recorder.startStreaming()).called(1);
          expect(sent, isEmpty);
          expect(await note.levels().first, equals(0.5));
        },
      );

      test('with live off, streams nothing', () async {
        await subject().start(surface: 'signup', live: Future.value(false));
        chunks.add(one);
        await settle();

        expect(sent, isEmpty);
      });

      test(
        'buffers the samples until the relay is ready, then streams them',
        () async {
          final note = subject();
          final words = <String>[];
          note.words.listen(words.add);
          await note.start(surface: 'signup', live: Future.value(true));
          chunks.add(one);
          await settle();
          expect(sent, isEmpty);

          ready.complete();
          await settle();
          chunks.add(two);
          await settle();
          fromRelay.add(frame({'type': 'ready'}));
          await settle();
          chunks.add(one);
          await settle();
          fromRelay.add(transcript('Hola'));
          await settle();

          expect(sent, hasLength(3));
          expect(
            sent[0],
            equals(frame({'idToken': 'id-token', 'surface': 'signup'})),
          );
          expect(sent[1], equals([1, 1, 2, 2]));
          expect(sent[2], same(one));
          expect(words, equals(['Hola']));
        },
      );

      test(
        'gives live up when more than maxBuffered waits for ready',
        () async {
          final note = subject(maxBuffered: Duration.zero);
          await note.start(surface: 'signup', live: Future.value(true));
          chunks.add(one);
          await settle();
          ready.complete();
          await settle();
          fromRelay.add(frame({'type': 'ready'}));
          await settle();
          chunks.add(two);
          await settle();

          final result = await note.stop();

          // The relay's ready came after live was given up: the session is
          // dropped and no audio ever went out.
          expect(sent, hasLength(1));
          expect(result.transcript, isNull);
          expect(result.wav, equals(wav));
        },
      );

      test('gives live up when the session fails to open', () async {
        final note = subject();
        await note.start(surface: 'signup', live: Future.value(true));
        chunks.add(one);
        ready.complete();
        await settle();
        fromRelay.add(frame({'type': 'error'}));
        await settle();
        chunks.add(two);
        await settle();

        final result = await note.stop();

        expect(sent, hasLength(1));
        expect(result.transcript, isNull);
        expect(result.wav, equals(wav));
      });

      test('gives live up when the terms check fails', () async {
        final note = subject();
        await note.start(
          surface: 'signup',
          live: Future.error(Exception('offline')),
        );
        chunks.add(one);
        ready.complete();
        await settle();

        final result = await note.stop();

        expect(sent, isEmpty);
        expect(result.transcript, isNull);
        expect(result.wav, equals(wav));
      });

      test('throws what the recorder throws, dropping the session', () async {
        when(() => recorder.startStreaming())
            .thenThrow(const VoiceRecorderException());
        ready.complete();

        await expectLater(
          subject().start(surface: 'signup', live: Future.value(true)),
          throwsA(isA<VoiceRecorderException>()),
        );

        // Live was given up before the session opened: nothing went out.
        expect(sent, isEmpty);
        verifyNever(() => sink.close());
      });
    });

    group('stop', () {
      Future<LiveVoiceNote> live() async {
        final note = subject();
        ready.complete();
        await note.start(surface: 'line', live: Future.value(true));
        await settle();
        fromRelay.add(frame({'type': 'ready'}));
        await settle();
        return note;
      }

      test('returns the WAV and the final transcript, trimmed', () async {
        final note = await live();
        chunks.add(one);
        await settle();

        final stopping = note.stop();
        await settle();
        fromRelay.add(transcript(' Hola, soy Marta. ', isFinal: true));
        final result = await stopping;

        expect(result.wav, equals(wav));
        expect(result.transcript, equals('Hola, soy Marta.'));
        expect(sent.last, equals(frame({'type': 'endStream'})));
      });

      test('returns no transcript when the final one is empty', () async {
        final note = await live();

        final stopping = note.stop();
        await settle();
        fromRelay.add(transcript('  ', isFinal: true));

        expect((await stopping).transcript, isNull);
      });

      test('returns no transcript when the final one is late', () async {
        final note = await live();

        final result = await note.stop();

        expect(result.transcript, isNull);
        expect(result.wav, equals(wav));
      });

      test(
        'returns no transcript when the relay dropped while recording',
        () async {
          final note = await live();
          fromRelay.addError(StateError('dropped'));
          await settle();

          expect((await note.stop()).transcript, isNull);
        },
      );

      test('returns what the recorder returns when nothing recorded', () async {
        when(() => recorder.stop()).thenAnswer((_) async {
          await chunks.close();
          return null;
        });
        final note = subject(withClient: false);
        await note.start(surface: 'signup', live: Future.value(false));

        final result = await note.stop();

        expect(result.wav, isNull);
        expect(result.transcript, isNull);
      });

      test('words close once the note is over', () async {
        final note = await live();
        final words = note.words.toList();

        await note.stop();

        expect(await words, isEmpty);
      });
    });

    group('cancel', () {
      test('throws the note and the session away', () async {
        final note = subject();
        ready.complete();
        await note.start(surface: 'plan', live: Future.value(true));
        await settle();
        fromRelay.add(frame({'type': 'ready'}));
        await settle();

        await note.cancel();

        verify(() => recorder.cancel()).called(1);
        expect(sent, hasLength(1));
        verify(() => sink.close()).called(1);
      });

      test('abandons a session still opening', () async {
        final note = subject();
        await note.start(surface: 'plan', live: Future.value(true));

        final cancelling = note.cancel();
        ready.complete();
        await settle();
        fromRelay.add(frame({'type': 'ready'}));
        await cancelling;

        expect(sent, hasLength(1));
        verify(() => sink.close()).called(1);
      });

      test('works with no client', () async {
        final note = subject(withClient: false);
        await note.start(surface: 'plan', live: Future.value(true));

        await note.cancel();

        verify(() => recorder.cancel()).called(1);
      });
    });
  });
}
