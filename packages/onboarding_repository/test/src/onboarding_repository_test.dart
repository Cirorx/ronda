import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_transcript/live_transcript.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:voice_recorder/voice_recorder.dart';

class _MockVoiceRecorder extends Mock implements VoiceRecorder;

class _MockLiveTranscriptClient extends Mock implements LiveTranscriptClient;

class _MockLiveTranscription extends Mock implements LiveTranscription;

class _MockRondaApi extends Mock implements RondaApi;

void main() {
  group(OnboardingRepository, () {
    late VoiceRecorder voiceRecorder;
    late RondaApi rondaApi;
    late OnboardingRepository subject;

    const uid = 'demo-uid';
    const path = 'audio/demo-uid/note-1.wav';
    // A header and a little sound.
    final wav = Uint8List(48);
    final withTerms = UserDocument(
      terms: TermsRecord(
        version: '2026-10-27',
        acceptedAt: DateTime(2026, 10, 28),
      ),
    );
    const fields = ExtractedFields(
      firstName: 'Graciela',
      ageBand: '60-69',
      barrio: 'solymar-norte',
      pretexts: ['mate'],
      slots: ['tue-afternoon'],
      brings: ['termo'],
    );

    setUpAll(() => registerFallbackValue(Uint8List(0)));

    setUp(() {
      voiceRecorder = _MockVoiceRecorder();
      rondaApi = _MockRondaApi();
      subject = OnboardingRepository(
        voiceRecorder: voiceRecorder,
        rondaApi: rondaApi,
        newNoteId: () => 'note-1',
      );
      when(() => voiceRecorder.stop()).thenAnswer((_) async => wav);
      when(() => rondaApi.readUser(uid)).thenAnswer((_) async => withTerms);
      when(
        () => rondaApi.uploadVoiceNote(
          uid: any(named: 'uid'),
          noteId: any(named: 'noteId'),
          wav: any(named: 'wav'),
        ),
      ).thenAnswer((_) async => path);
      when(() => rondaApi.extract(path)).thenAnswer((_) async => fields);
      when(() => rondaApi.deleteVoiceNote(path)).thenAnswer((_) async {});
    });

    test('names notes with 32 random hex characters by default', () async {
      final ids = <String>[];
      when(
        () => rondaApi.uploadVoiceNote(
          uid: any(named: 'uid'),
          noteId: any(named: 'noteId'),
          wav: any(named: 'wav'),
        ),
      ).thenAnswer((invocation) async {
        ids.add(invocation.namedArguments[#noteId] as String);
        return path;
      });
      final random = OnboardingRepository(
        voiceRecorder: voiceRecorder,
        rondaApi: rondaApi,
      );

      await random.readVoiceNote(uid);
      await random.readVoiceNote(uid);

      expect(ids.first, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(ids.first, isNot(equals(ids.last)));
    });

    group('startVoiceNote', () {
      test('starts the recorder when the microphone is allowed', () async {
        when(() => voiceRecorder.hasPermission()).thenAnswer((_) async => true);
        when(() => voiceRecorder.startStreaming())
            .thenAnswer((_) async => const Stream.empty());

        await subject.startVoiceNote(uid);

        verify(() => voiceRecorder.startStreaming()).called(1);
      });

      test('throws $MicrophoneDeniedFailure without the microphone', () {
        when(() => voiceRecorder.hasPermission())
            .thenAnswer((_) async => false);
        when(() => voiceRecorder.hasMicrophone()).thenAnswer((_) async => true);

        expect(
          subject.startVoiceNote(uid),
          throwsA(isA<MicrophoneDeniedFailure>()),
        );
        verifyNever(() => voiceRecorder.startStreaming());
      });

      test('throws $NoMicrophoneFailure when there is none', () {
        when(() => voiceRecorder.hasPermission())
            .thenAnswer((_) async => false);
        when(() => voiceRecorder.hasMicrophone())
            .thenAnswer((_) async => false);

        expect(
          subject.startVoiceNote(uid),
          throwsA(isA<NoMicrophoneFailure>()),
        );
        verifyNever(() => voiceRecorder.startStreaming());
      });

      test('throws $StartVoiceNoteFailure when asking fails', () {
        when(() => voiceRecorder.hasPermission()).thenThrow(Exception());

        expect(
          subject.startVoiceNote(uid),
          throwsA(isA<StartVoiceNoteFailure>()),
        );
      });

      test('throws $StartVoiceNoteFailure when the recorder fails', () {
        when(() => voiceRecorder.hasPermission()).thenAnswer((_) async => true);
        when(() => voiceRecorder.startStreaming()).thenThrow(Exception());

        expect(
          subject.startVoiceNote(uid),
          throwsA(isA<StartVoiceNoteFailure>()),
        );
      });
    });

    test('voiceLevels passes the recorder levels on', () {
      when(() => voiceRecorder.levels())
          .thenAnswer((_) => Stream.fromIterable([0, 0.5]));

      expect(subject.voiceLevels(), emitsInOrder([0, 0.5, emitsDone]));
    });

    group('discardVoiceNote', () {
      test('cancels the recorder', () async {
        when(() => voiceRecorder.cancel()).thenAnswer((_) async {});

        await subject.discardVoiceNote();

        verify(() => voiceRecorder.cancel()).called(1);
      });

      test('ignores a recorder with nothing to cancel', () async {
        when(() => voiceRecorder.cancel()).thenThrow(Exception());

        await expectLater(subject.discardVoiceNote(), completes);
      });
    });

    group('readVoiceNote', () {
      test('uploads the note, awaits extract and returns the fields', () async {
        expect(
          await subject.readVoiceNote(uid),
          equals(
            const VoiceSignup(
              firstName: 'Graciela',
              ageBand: '60-69',
              barrio: 'solymar-norte',
              pretexts: ['mate'],
              slots: ['tue-afternoon'],
              brings: ['termo'],
            ),
          ),
        );
        verify(
          () => rondaApi.uploadVoiceNote(uid: uid, noteId: 'note-1', wav: wav),
        ).called(1);
        verifyNever(() => rondaApi.deleteVoiceNote(any()));
      });

      test('refuses to upload while users/{uid}.terms is missing', () async {
        when(() => rondaApi.readUser(uid))
            .thenAnswer((_) async => const UserDocument(firstName: 'Graciela'));

        await expectLater(
          subject.readVoiceNote(uid),
          throwsA(isA<TermsNotAcceptedFailure>()),
        );
        verifyNever(
          () => rondaApi.uploadVoiceNote(
            uid: any(named: 'uid'),
            noteId: any(named: 'noteId'),
            wav: any(named: 'wav'),
          ),
        );
        verifyNever(() => rondaApi.extract(any()));
      });

      test('refuses to upload while users/{uid} does not exist', () async {
        when(() => rondaApi.readUser(uid)).thenAnswer((_) async => null);

        await expectLater(
          subject.readVoiceNote(uid),
          throwsA(isA<TermsNotAcceptedFailure>()),
        );
        verifyNever(
          () => rondaApi.uploadVoiceNote(
            uid: any(named: 'uid'),
            noteId: any(named: 'noteId'),
            wav: any(named: 'wav'),
          ),
        );
      });

      test('throws $RecordVoiceNoteFailure when nothing was recorded', () {
        when(() => voiceRecorder.stop()).thenAnswer((_) async => null);

        expect(
          subject.readVoiceNote(uid),
          throwsA(isA<RecordVoiceNoteFailure>()),
        );
      });

      test('throws $RecordVoiceNoteFailure for a header with no sound', () {
        when(() => voiceRecorder.stop()).thenAnswer((_) async => Uint8List(44));

        expect(
          subject.readVoiceNote(uid),
          throwsA(isA<RecordVoiceNoteFailure>()),
        );
        verifyNever(() => rondaApi.readUser(any()));
      });

      test('throws $RecordVoiceNoteFailure when stopping fails', () {
        when(() => voiceRecorder.stop()).thenThrow(Exception());

        expect(
          subject.readVoiceNote(uid),
          throwsA(isA<RecordVoiceNoteFailure>()),
        );
      });

      test('throws $UploadVoiceNoteFailure when the terms read fails', () {
        when(() => rondaApi.readUser(uid)).thenThrow(Exception());

        expect(
          subject.readVoiceNote(uid),
          throwsA(
            isA<UploadVoiceNoteFailure>()
                .having((f) => f.refused, 'refused', isFalse)
                .having((f) => f.code, 'code', 'read-user'),
          ),
        );
      });

      void uploadThrows(Object error) => when(
        () => rondaApi.uploadVoiceNote(
          uid: any(named: 'uid'),
          noteId: any(named: 'noteId'),
          wav: any(named: 'wav'),
        ),
      ).thenThrow(error);

      test('throws a refused $UploadVoiceNoteFailure when Storage says no', () {
        uploadThrows(const VoiceNoteRefusedException('unauthorized'));

        expect(
          subject.readVoiceNote(uid),
          throwsA(
            isA<UploadVoiceNoteFailure>()
                .having((f) => f.refused, 'refused', isTrue)
                .having((f) => f.code, 'code', 'unauthorized'),
          ),
        );
        verifyNever(() => rondaApi.extract(any()));
      });

      test('throws $UploadVoiceNoteFailure when the upload fails', () {
        uploadThrows(const VoiceNoteUploadException('retry-limit-exceeded'));

        expect(
          subject.readVoiceNote(uid),
          throwsA(
            isA<UploadVoiceNoteFailure>()
                .having((f) => f.refused, 'refused', isFalse)
                .having((f) => f.code, 'code', 'retry-limit-exceeded'),
          ),
        );
      });

      test('throws $UploadVoiceNoteFailure on any other upload error', () {
        uploadThrows(Exception());

        expect(
          subject.readVoiceNote(uid),
          throwsA(
            isA<UploadVoiceNoteFailure>()
                .having((f) => f.refused, 'refused', isFalse)
                .having((f) => f.code, 'code', isNull),
          ),
        );
      });

      test('throws $VoiceNoteNotUnderstoodFailure for an unreadable note', () {
        when(() => rondaApi.extract(path))
            .thenThrow(const UnreadableVoiceNoteException());

        expect(
          subject.readVoiceNote(uid),
          throwsA(isA<VoiceNoteNotUnderstoodFailure>()),
        );
      });

      test('throws $VoiceNoteNotUnderstoodFailure when nothing was '
          'understood', () {
        when(() => rondaApi.extract(path))
            .thenAnswer((_) async => const ExtractedFields());

        expect(
          subject.readVoiceNote(uid),
          throwsA(isA<VoiceNoteNotUnderstoodFailure>()),
        );
      });

      test('deletes the note and throws $ReadVoiceNoteFailure when extract '
          'fails', () async {
        when(() => rondaApi.extract(path)).thenThrow(
          FirebaseFunctionsException(message: 'm', code: 'unavailable'),
        );

        await expectLater(
          subject.readVoiceNote(uid),
          throwsA(isA<ReadVoiceNoteFailure>()),
        );
        verify(() => rondaApi.deleteVoiceNote(path)).called(1);
      });

      test('still throws $ReadVoiceNoteFailure when that delete fails', () {
        when(() => rondaApi.extract(path)).thenThrow(Exception());
        when(() => rondaApi.deleteVoiceNote(path)).thenThrow(Exception());

        expect(
          subject.readVoiceNote(uid),
          throwsA(isA<ReadVoiceNoteFailure>()),
        );
      });
    });
  });

  group('$OnboardingRepository with live transcription', () {
    late VoiceRecorder voiceRecorder;
    late RondaApi rondaApi;
    late LiveTranscriptClient liveTranscript;
    late LiveTranscription session;
    late StreamController<String> heard;
    late OnboardingRepository subject;

    const uid = 'demo-uid';
    const path = 'audio/demo-uid/note-1.wav';
    final wav = Uint8List(48);
    final withTerms = UserDocument(
      terms: TermsRecord(
        version: '2026-10-27',
        acceptedAt: DateTime(2026, 10, 28),
      ),
    );
    const fields = ExtractedFields(firstName: 'Graciela', ageBand: '60-69');
    const signup = VoiceSignup(firstName: 'Graciela', ageBand: '60-69');

    setUpAll(() => registerFallbackValue(Uint8List(0)));

    setUp(() {
      voiceRecorder = _MockVoiceRecorder();
      rondaApi = _MockRondaApi();
      liveTranscript = _MockLiveTranscriptClient();
      session = _MockLiveTranscription();
      heard = StreamController<String>.broadcast();
      subject = OnboardingRepository(
        voiceRecorder: voiceRecorder,
        rondaApi: rondaApi,
        liveTranscript: liveTranscript,
        newNoteId: () => 'note-1',
      );
      when(() => voiceRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => voiceRecorder.startStreaming())
          .thenAnswer((_) async => const Stream.empty());
      when(() => voiceRecorder.stop()).thenAnswer((_) async => wav);
      when(() => voiceRecorder.cancel()).thenAnswer((_) async {});
      when(() => rondaApi.readUser(uid)).thenAnswer((_) async => withTerms);
      when(() => liveTranscript.start(OnboardingRepository.liveSurface))
          .thenAnswer((_) async => session);
      when(() => session.words).thenAnswer((_) => heard.stream);
      when(() => session.isOver).thenReturn(false);
      when(() => session.finish()).thenAnswer((_) async => 'Hola, soy Marta.');
      when(() => session.abandon()).thenAnswer((_) async {});
      when(() => rondaApi.readTranscript('Hola, soy Marta.'))
          .thenAnswer((_) async => fields);
      when(
        () => rondaApi.uploadVoiceNote(
          uid: any(named: 'uid'),
          noteId: any(named: 'noteId'),
          wav: any(named: 'wav'),
        ),
      ).thenAnswer((_) async => path);
      when(() => rondaApi.extract(path)).thenAnswer((_) async => fields);
    });

    tearDown(() => heard.close());

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('shows the words as they come and reads the final transcript with '
        'read_transcript, uploading nothing', () async {
      await subject.startVoiceNote(uid);
      await settle();
      final words = subject.liveWords().first;
      await settle();
      heard.add('Hola');

      expect(await subject.readVoiceNote(uid), equals(signup));
      expect(await words, equals('Hola'));
      verify(() => liveTranscript.start('signup')).called(1);
      verifyNever(
        () => rondaApi.uploadVoiceNote(
          uid: any(named: 'uid'),
          noteId: any(named: 'noteId'),
          wav: any(named: 'wav'),
        ),
      );
      verifyNever(() => rondaApi.extract(any()));
    });

    test('liveWords is silent before a note starts', () {
      expect(subject.liveWords(), emitsDone);
    });

    test('records without live while users/{uid}.terms is missing', () async {
      when(() => rondaApi.readUser(uid)).thenAnswer((_) async => null);

      await subject.startVoiceNote(uid);
      await settle();

      verifyNever(() => liveTranscript.start(any()));
      await expectLater(
        subject.readVoiceNote(uid),
        throwsA(isA<TermsNotAcceptedFailure>()),
      );
    });

    test('records without live when the terms read fails', () async {
      when(() => rondaApi.readUser(uid)).thenThrow(Exception('offline'));

      await subject.startVoiceNote(uid);
      await settle();

      verifyNever(() => liveTranscript.start(any()));
    });

    test('falls back to the upload when the session cannot open', () async {
      when(() => liveTranscript.start(any()))
          .thenThrow(const LiveTranscriptException());

      await subject.startVoiceNote(uid);
      await settle();

      expect(await subject.readVoiceNote(uid), equals(signup));
      verify(() => rondaApi.extract(path)).called(1);
    });

    test(
      'falls back to the upload when the final transcript never comes',
      () async {
        when(() => session.finish()).thenAnswer((_) async => null);

        await subject.startVoiceNote(uid);
        await settle();

        expect(await subject.readVoiceNote(uid), equals(signup));
        verify(() => rondaApi.extract(path)).called(1);
        verifyNever(() => rondaApi.readTranscript(any()));
      },
    );

    test('falls back to the upload when read_transcript fails', () async {
      when(() => rondaApi.readTranscript(any()))
          .thenThrow(Exception('offline'));

      await subject.startVoiceNote(uid);
      await settle();

      expect(await subject.readVoiceNote(uid), equals(signup));
      verify(() => rondaApi.extract(path)).called(1);
    });

    test('throws $VoiceNoteNotUnderstoodFailure when read_transcript cannot '
        'read the words', () async {
      when(() => rondaApi.readTranscript(any()))
          .thenThrow(const UnreadableVoiceNoteException());

      await subject.startVoiceNote(uid);
      await settle();

      await expectLater(
        subject.readVoiceNote(uid),
        throwsA(isA<VoiceNoteNotUnderstoodFailure>()),
      );
      verifyNever(() => rondaApi.extract(any()));
    });

    test('throws $VoiceNoteNotUnderstoodFailure when nothing was understood '
        'of the words', () async {
      when(() => rondaApi.readTranscript(any()))
          .thenAnswer((_) async => const ExtractedFields());

      await subject.startVoiceNote(uid);
      await settle();

      await expectLater(
        subject.readVoiceNote(uid),
        throwsA(isA<VoiceNoteNotUnderstoodFailure>()),
      );
    });

    test('discardVoiceNote drops the session with the note', () async {
      await subject.startVoiceNote(uid);
      await settle();

      await subject.discardVoiceNote();

      verify(() => voiceRecorder.cancel()).called(1);
      verify(() => session.abandon()).called(1);
    });
  });

  group(VoiceSignup, () {
    test('is empty when nothing was understood', () {
      expect(const VoiceSignup().isEmpty, isTrue);
      expect(const VoiceSignup(slots: ['tue-afternoon']).isEmpty, isFalse);
    });
  });
}
