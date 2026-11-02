import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_transcript/live_transcript.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _MockWebSocketChannel extends Mock implements WebSocketChannel;

class _MockWebSocketSink extends Mock implements WebSocketSink;

void main() {
  group(LiveTranscriptClient, () {
    late WebSocketChannel channel;
    late WebSocketSink sink;
    late StreamController<dynamic> fromRelay;
    late List<Object?> sent;
    late List<Uri> connected;
    late Completer<void> ready;

    final url = Uri.parse('wss://relay.example/v1/live');

    String frame(Map<String, Object?> event) => jsonEncode(event);

    setUp(() {
      channel = _MockWebSocketChannel();
      sink = _MockWebSocketSink();
      fromRelay = StreamController<dynamic>();
      sent = [];
      connected = [];
      ready = Completer<void>();
      when(() => channel.ready).thenAnswer((_) => ready.future);
      when(() => channel.stream).thenAnswer((_) => fromRelay.stream);
      when(() => channel.sink).thenReturn(sink);
      when(() => sink.add(any<Object?>())).thenAnswer(
        (invocation) => sent.add(invocation.positionalArguments.single),
      );
      when(() => sink.close()).thenAnswer((_) async {});
    });

    LiveTranscriptClient subject({
      Future<String?> Function()? idToken,
      WebSocketChannel Function(Uri)? connect,
      Duration readyTimeout = const Duration(milliseconds: 50),
      Duration finalTimeout = const Duration(milliseconds: 50),
    }) => LiveTranscriptClient(
      url: url,
      idToken: idToken ?? () async => 'id-token',
      connect:
          connect ??
          (uri) {
            connected.add(uri);
            return channel;
          },
      readyTimeout: readyTimeout,
      finalTimeout: finalTimeout,
    );

    /// A session the relay said `ready` to.
    Future<LiveTranscription> started() async {
      ready.complete();
      final session = subject().start('signup');
      await Future<void>.delayed(Duration.zero);
      fromRelay.add(frame({'type': 'ready'}));
      return await session;
    }

    test('connects to the real socket by default', () {
      expect(
        LiveTranscriptClient(url: url, idToken: () async => null),
        isA<LiveTranscriptClient>(),
      );
    });

    group('start', () {
      test('connects to the relay and sends the id token and the surface '
          'first, then is ready once the relay says so', () async {
        final session = await started();

        expect(connected, equals([url]));
        expect(
          sent,
          equals([
            frame({'idToken': 'id-token', 'surface': 'signup'}),
          ]),
        );
        expect(session.isOver, isFalse);
      });

      test(
        'throws $LiveTranscriptException when there is no id token',
        () async {
          await expectLater(
            subject(idToken: () async => null).start('signup'),
            throwsA(isA<LiveTranscriptException>()),
          );
          expect(connected, isEmpty);
        },
      );

      test('throws $LiveTranscriptException when the id token fails', () async {
        await expectLater(
          subject(idToken: () async => throw Exception('signed out'))
              .start('signup'),
          throwsA(isA<LiveTranscriptException>()),
        );
      });

      test('throws $LiveTranscriptException when connecting throws', () async {
        await expectLater(
          subject(connect: (_) => throw StateError('no socket'))
              .start('signup'),
          throwsA(isA<LiveTranscriptException>()),
        );
      });

      test(
        'throws $LiveTranscriptException when the socket never opens',
        () async {
          await expectLater(
            subject().start('signup'),
            throwsA(isA<LiveTranscriptException>()),
          );
          verify(() => sink.close()).called(1);
        },
      );

      test('throws $LiveTranscriptException when the relay refuses', () async {
        ready.complete();
        final session = subject().start('signup');
        await Future<void>.delayed(Duration.zero);
        fromRelay.add(frame({'type': 'error', 'code': 'terms'}));

        await expectLater(session, throwsA(isA<LiveTranscriptException>()));
      });

      test('throws $LiveTranscriptException when the relay closes before '
          'ready', () async {
        ready.complete();
        final session = subject().start('signup');
        await Future<void>.delayed(Duration.zero);
        await fromRelay.close();

        await expectLater(session, throwsA(isA<LiveTranscriptException>()));
      });

      test('throws $LiveTranscriptException when ready never comes', () async {
        ready.complete();

        await expectLater(
          subject().start('signup'),
          throwsA(isA<LiveTranscriptException>()),
        );
      });
    });

    group(LiveTranscription, () {
      test('words carry each transcript the relay forwards', () async {
        final session = await started();
        final words = <String>[];
        session.words.listen(words.add);

        fromRelay
          ..add(
            frame({'type': 'transcript', 'transcript': 'Hola', 'final': false}),
          )
          ..add(
            frame({
              'type': 'transcript',
              'transcript': 'Hola, soy',
              'final': false,
            }),
          )
          ..add(frame({'type': 'speechStart', 'turnId': 1}))
          ..add('not json')
          ..add(Uint8List(2));
        await Future<void>.delayed(Duration.zero);

        expect(words, equals(['Hola', 'Hola, soy']));
      });

      test('add sends the samples as binary frames', () async {
        final session = await started();
        final pcm = Uint8List.fromList([1, 2, 3, 4]);

        session.add(pcm);

        expect(sent.last, same(pcm));
      });

      test(
        'finish sends endStream, returns the final transcript and closes',
        () async {
          final session = await started();
          final words = session.words.toList();

          final finishing = session.finish();
          await Future<void>.delayed(Duration.zero);
          fromRelay.add(
            frame({
              'type': 'transcript',
              'transcript': 'Hola, soy Marta.',
              'final': true,
            }),
          );

          expect(await finishing, equals('Hola, soy Marta.'));
          expect(sent.last, equals(frame({'type': 'endStream'})));
          expect(session.isOver, isTrue);
          expect(await words, equals(['Hola, soy Marta.']));
          verify(() => sink.close()).called(1);
          session.add(Uint8List(2));
          expect(sent.last, equals(frame({'type': 'endStream'})));
        },
      );

      test('finish returns null when the final transcript is late', () async {
        final session = await started();

        expect(await session.finish(), isNull);
        expect(session.isOver, isTrue);
      });

      test('finish returns null when the relay fails first', () async {
        final session = await started();
        fromRelay.add(frame({'type': 'error', 'code': 'upstream'}));
        await Future<void>.delayed(Duration.zero);

        expect(await session.finish(), isNull);
        // endStream is not sent to a session that is over.
        expect(sent, hasLength(1));
      });

      test('finish returns null when the socket drops', () async {
        final session = await started();
        fromRelay.addError(StateError('dropped'));
        await Future<void>.delayed(Duration.zero);

        expect(await session.finish(), isNull);
      });

      test('a frame that is not JSON after ready ends the session', () async {
        final session = await started();
        fromRelay.add('{not json');
        await Future<void>.delayed(Duration.zero);

        expect(session.isOver, isTrue);
      });

      test('closing the sink may fail once the relay closed', () async {
        when(() => sink.close()).thenThrow(StateError('closed'));
        final session = await started();

        await session.abandon();

        expect(session.isOver, isTrue);
      });

      test('abandon drops the session and sends nothing more', () async {
        final session = await started();

        await session.abandon();
        session.add(Uint8List(2));

        expect(session.isOver, isTrue);
        expect(sent, hasLength(1));
        expect(await session.finish(), isNull);
      });
    });
  });
}
