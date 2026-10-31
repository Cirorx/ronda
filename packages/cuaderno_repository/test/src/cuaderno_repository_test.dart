import 'dart:convert';
import 'dart:typed_data';

import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:device_store/device_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:share_sheet/share_sheet.dart';
import 'package:voice_recorder/voice_recorder.dart';

class _MockDeviceStore extends Mock implements DeviceStore;

class _MockVoiceRecorder extends Mock implements VoiceRecorder;

class _MockRondaApi extends Mock implements RondaApi;

class _MockCuadernoApi extends Mock implements CuadernoApi;

class _MockShareSheet extends Mock implements ShareSheet;

void main() {
  group(CuadernoRepository, () {
    late DeviceStore deviceStore;
    late VoiceRecorder voiceRecorder;
    late RondaApi rondaApi;
    late CuadernoApi cuadernoApi;
    late ShareSheet shareSheet;
    late CuadernoRepository subject;
    late Map<String, String> stored;

    const uid = 'demo-uid';
    const key = 'cuaderno.demo-uid';
    const path = 'audio/demo-uid/note-1.wav';
    final monday = DateTime(2026, 10, 26);
    final tuesday = DateTime(2026, 10, 27, 18, 30);
    final wednesday = DateTime(2026, 10, 28);
    // A header and a little sound.
    final wav = Uint8List(48);
    final withTerms = UserDocument(
      terms: TermsRecord(
        version: '2026-10-27',
        acceptedAt: DateTime(2026, 10, 28),
      ),
    );

    setUpAll(() => registerFallbackValue(Uint8List(0)));

    setUp(() {
      deviceStore = _MockDeviceStore();
      voiceRecorder = _MockVoiceRecorder();
      rondaApi = _MockRondaApi();
      cuadernoApi = _MockCuadernoApi();
      shareSheet = _MockShareSheet();
      stored = {};
      subject = CuadernoRepository(
        deviceStore: deviceStore,
        voiceRecorder: voiceRecorder,
        rondaApi: rondaApi,
        cuadernoApi: cuadernoApi,
        shareSheet: shareSheet,
        newNoteId: () => 'note-1',
      );
      when(() => deviceStore.read(any())).thenAnswer(
        (invocation) async => stored[invocation.positionalArguments.single],
      );
      when(() => deviceStore.write(any(), any()))
          .thenAnswer((invocation) async {
            stored[invocation.positionalArguments[0] as String] =
                invocation.positionalArguments[1] as String;
          });
      when(() => deviceStore.delete(any())).thenAnswer((invocation) async {
        stored.remove(invocation.positionalArguments.single);
      });
    });

    group('the cuaderno on the phone', () {
      test('is empty before anything is written', () async {
        expect(await subject.read(uid), equals(Cuaderno.empty));
      });

      test("keeps a line under the person's own key", () async {
        final cuaderno = await subject.saveEntry(
          uid,
          day: tuesday,
          text: '  El jacarandá \n de la esquina  floreció. ',
        );

        expect(
          cuaderno.entries,
          equals([
            CuadernoEntry(
              day: DateTime(2026, 10, 27),
              text: 'El jacarandá de la esquina floreció.',
            ),
          ]),
        );
        expect(stored.keys, equals([key]));
        expect(await subject.read(uid), equals(cuaderno));
      });

      test("keeps each person's cuaderno apart", () async {
        await subject.saveEntry(uid, day: monday, text: 'uno');

        expect(await subject.read('other-uid'), equals(Cuaderno.empty));
      });

      test('keeps one line a day: writing again replaces it', () async {
        await subject.saveEntry(uid, day: monday, text: 'uno');
        final cuaderno = await subject.saveEntry(
          uid,
          day: DateTime(2026, 10, 26, 22),
          text: 'otro',
        );

        expect(cuaderno.entries.map((e) => e.text), equals(['otro']));
      });

      test('lists the lines newest first', () async {
        await subject.saveEntry(uid, day: tuesday, text: 'martes');
        await subject.saveEntry(uid, day: monday, text: 'lunes');
        final cuaderno = await subject.saveEntry(
          uid,
          day: wednesday,
          text: 'miércoles',
        );

        expect(
          cuaderno.entries.map((e) => e.text),
          equals(['miércoles', 'martes', 'lunes']),
        );
      });

      test('cuts a line at its limit', () async {
        final cuaderno = await subject.saveEntry(
          uid,
          day: monday,
          text: 'a' * (CuadernoEntry.maxLength + 20),
        );

        expect(
          cuaderno.entries.single.text,
          hasLength(CuadernoEntry.maxLength),
        );
      });

      test('does not save an empty line', () async {
        final cuaderno = await subject.saveEntry(
          uid,
          day: monday,
          text: ' \n ',
        );

        expect(cuaderno, equals(Cuaderno.empty));
        expect(stored, isEmpty);
      });

      test('deletes a line', () async {
        await subject.saveEntry(uid, day: monday, text: 'uno');
        await subject.saveEntry(uid, day: tuesday, text: 'dos');

        final cuaderno = await subject.deleteEntry(uid, monday);

        expect(cuaderno.entries.map((e) => e.text), equals(['dos']));
      });

      test('chooses a line to bring, one at a time', () async {
        await subject.saveEntry(uid, day: monday, text: 'uno');
        await subject.saveEntry(uid, day: tuesday, text: 'dos');

        await subject.bring(uid, monday);
        final cuaderno = await subject.bring(uid, tuesday);

        expect(cuaderno.brought?.text, equals('dos'));
        expect((await subject.read(uid)).brought?.text, equals('dos'));
      });

      test('chooses none, or a day with no line, as none', () async {
        await subject.saveEntry(uid, day: monday, text: 'uno');
        await subject.bring(uid, monday);

        expect((await subject.bring(uid, null)).brought, isNull);
        expect((await subject.bring(uid, wednesday)).brought, isNull);
      });

      test('forgets the line to bring when it is deleted', () async {
        await subject.saveEntry(uid, day: monday, text: 'uno');
        await subject.saveEntry(uid, day: tuesday, text: 'dos');
        await subject.bring(uid, monday);

        final deleted = await subject.deleteEntry(uid, monday);
        final other = await subject.deleteEntry(uid, wednesday);

        expect(deleted.bringDay, isNull);
        expect(other.bringDay, isNull);
      });

      test('keeps the line to bring when another is deleted', () async {
        await subject.saveEntry(uid, day: monday, text: 'uno');
        await subject.saveEntry(uid, day: tuesday, text: 'dos');
        await subject.bring(uid, monday);

        expect((await subject.deleteEntry(uid, tuesday)).brought?.text, 'uno');
      });

      test('keeps the line to bring when it is rewritten', () async {
        await subject.saveEntry(uid, day: monday, text: 'uno');
        await subject.bring(uid, monday);

        final cuaderno = await subject.saveEntry(
          uid,
          day: monday,
          text: 'uno de nuevo',
        );

        expect(cuaderno.brought?.text, equals('uno de nuevo'));
      });

      test('is deleted in one action', () async {
        await subject.saveEntry(uid, day: monday, text: 'uno');

        await subject.clear(uid);

        expect(stored, isEmpty);
        expect(await subject.read(uid), equals(Cuaderno.empty));
      });

      test('says when it changes', () async {
        final changes = <void>[];
        final subscription = subject.changes.listen(changes.add);

        await subject.saveEntry(uid, day: monday, text: 'uno');
        await subject.bring(uid, monday);
        await subject.deleteEntry(uid, monday);
        await subject.clear(uid);
        await Future<void>.delayed(Duration.zero);

        expect(changes, hasLength(4));
        await subscription.cancel();
      });

      group('reads what is stored', () {
        for (final (name, value) in [
          ('something that is not JSON', 'not json'),
          ('JSON that is not a map', '[1]'),
          ('a map with no entries', '{"bring":"2026-10-26"}'),
        ]) {
          test('as an empty cuaderno for $name', () async {
            stored[key] = value;

            expect(await subject.read(uid), equals(Cuaderno.empty));
          });
        }

        test('skipping what it cannot read', () async {
          stored[key] = jsonEncode({
            'entries': [
              {'day': '2026-10-26', 'text': 'uno'},
              {'day': 'mañana', 'text': 'sin día'},
              {'day': 3, 'text': 'sin día'},
              {'day': '2026-10-27', 'text': ''},
              {'day': '2026-10-28'},
              'dos',
            ],
            'bring': 'ayer',
          });

          final cuaderno = await subject.read(uid);

          expect(cuaderno.entries.map((e) => e.text), equals(['uno']));
          expect(cuaderno.bringDay, isNull);
        });
      });
    });

    group('Cuaderno', () {
      final cuaderno = Cuaderno(
        entries: [
          CuadernoEntry(day: wednesday, text: 'miércoles'),
          CuadernoEntry(day: DateTime(2026, 10, 27), text: 'martes'),
          CuadernoEntry(day: monday, text: 'lunes'),
        ],
      );

      test('finds the line of a day', () {
        expect(cuaderno.on(DateTime(2026, 10, 27, 9))?.text, equals('martes'));
        expect(cuaderno.on(DateTime(2026, 11)), isNull);
      });

      test('lists the lines between two days, oldest first', () {
        expect(
          cuaderno
              .between(monday, DateTime(2026, 10, 27, 23))
              .map((e) => e.text),
          equals(['lunes', 'martes']),
        );
        expect(
          cuaderno.between(DateTime(2026, 11), DateTime(2026, 11, 7)),
          isEmpty,
        );
      });
    });

    group('the entries never leave the phone', () {
      test(
        'writing, reading, bringing and deleting touch only the store',
        () async {
          await subject.saveEntry(uid, day: monday, text: 'uno');
          await subject.bring(uid, monday);
          await subject.read(uid);
          await subject.deleteEntry(uid, monday);
          await subject.clear(uid);

          verifyZeroInteractions(rondaApi);
          verifyZeroInteractions(cuadernoApi);
          verifyZeroInteractions(shareSheet);
          verifyZeroInteractions(voiceRecorder);
        },
      );

      test('the postcard sends only the lines it is given', () async {
        await subject.saveEntry(uid, day: monday, text: 'uno');
        when(() => cuadernoApi.makePostcard(any()))
            .thenAnswer((_) async => wav);

        await subject.makePostcard(['dos']);

        verify(() => cuadernoApi.makePostcard(['dos'])).called(1);
        verifyNoMoreInteractions(cuadernoApi);
        verifyZeroInteractions(rondaApi);
      });
    });

    group('startVoiceNote', () {
      setUp(() {
        when(() => voiceRecorder.hasPermission()).thenAnswer((_) async => true);
        when(() => voiceRecorder.hasMicrophone()).thenAnswer((_) async => true);
        when(() => voiceRecorder.start()).thenAnswer((_) async {});
      });

      test('starts the recorder', () async {
        await subject.startVoiceNote();

        verify(() => voiceRecorder.start()).called(1);
      });

      test('says there is no microphone', () {
        when(() => voiceRecorder.hasPermission())
            .thenAnswer((_) async => false);
        when(() => voiceRecorder.hasMicrophone())
            .thenAnswer((_) async => false);

        expect(subject.startVoiceNote(), _fails(VoiceLineProblem.noMicrophone));
      });

      test('says the microphone was refused', () {
        when(() => voiceRecorder.hasPermission())
            .thenAnswer((_) async => false);

        expect(
          subject.startVoiceNote(),
          _fails(VoiceLineProblem.microphoneDenied),
        );
      });

      test('says the recorder failed to answer', () {
        when(() => voiceRecorder.hasPermission()).thenThrow(Exception('x'));

        expect(
          subject.startVoiceNote(),
          _fails(VoiceLineProblem.recorderFailed),
        );
      });

      test('says the recorder failed to start', () {
        when(() => voiceRecorder.start()).thenThrow(Exception('x'));

        expect(
          subject.startVoiceNote(),
          _fails(VoiceLineProblem.recorderFailed),
        );
      });
    });

    group('the recorder', () {
      test('reports levels', () {
        when(() => voiceRecorder.levels()).thenAnswer((_) => Stream.value(0.5));

        expect(subject.voiceLevels(), emits(0.5));
      });

      test('discards a note', () async {
        when(() => voiceRecorder.cancel()).thenAnswer((_) async {});

        await subject.discardVoiceNote();

        verify(() => voiceRecorder.cancel()).called(1);
      });

      test('has nothing to discard when it was not recording', () async {
        when(() => voiceRecorder.cancel()).thenThrow(Exception('x'));

        await expectLater(subject.discardVoiceNote(), completes);
      });
    });

    group('readVoiceLine', () {
      setUp(() {
        when(() => voiceRecorder.stop()).thenAnswer((_) async => wav);
        when(() => rondaApi.readUser(uid)).thenAnswer((_) async => withTerms);
        when(
          () => rondaApi.uploadVoiceNote(
            uid: any(named: 'uid'),
            noteId: any(named: 'noteId'),
            wav: any(named: 'wav'),
          ),
        ).thenAnswer((_) async => path);
        when(() => cuadernoApi.readLine(path))
            .thenAnswer((_) async => 'El jacarandá floreció.');
        when(() => rondaApi.deleteVoiceNote(path)).thenAnswer((_) async {});
      });

      test('uploads the note and returns the words, writing nothing', () async {
        expect(
          await subject.readVoiceLine(uid),
          equals('El jacarandá floreció.'),
        );

        verify(
          () => rondaApi.uploadVoiceNote(uid: uid, noteId: 'note-1', wav: wav),
        ).called(1);
        verify(() => cuadernoApi.readLine(path)).called(1);
        verifyNever(() => rondaApi.deleteVoiceNote(any()));
        verifyNever(() => deviceStore.write(any(), any()));
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
        final random = CuadernoRepository(
          deviceStore: deviceStore,
          voiceRecorder: voiceRecorder,
          rondaApi: rondaApi,
          cuadernoApi: cuadernoApi,
          shareSheet: shareSheet,
        );

        await random.readVoiceLine(uid);
        await random.readVoiceLine(uid);

        expect(ids.first, matches(RegExp(r'^[0-9a-f]{32}$')));
        expect(ids.first, isNot(equals(ids.last)));
      });

      test('fails when the recorder gives back nothing', () {
        when(() => voiceRecorder.stop()).thenAnswer((_) async => null);

        expect(
          subject.readVoiceLine(uid),
          _fails(VoiceLineProblem.recorderFailed),
        );
      });

      test('fails when the note has no sound in it', () {
        when(() => voiceRecorder.stop()).thenAnswer((_) async => Uint8List(44));

        expect(
          subject.readVoiceLine(uid),
          _fails(VoiceLineProblem.recorderFailed),
        );
      });

      test('fails when the recorder fails', () {
        when(() => voiceRecorder.stop()).thenThrow(Exception('x'));

        expect(
          subject.readVoiceLine(uid),
          _fails(VoiceLineProblem.recorderFailed),
        );
      });

      test('sends nothing before the terms', () async {
        when(() => rondaApi.readUser(uid))
            .thenAnswer((_) async => const UserDocument());

        await expectLater(
          subject.readVoiceLine(uid),
          _fails(VoiceLineProblem.termsMissing),
        );
        verifyNever(
          () => rondaApi.uploadVoiceNote(
            uid: any(named: 'uid'),
            noteId: any(named: 'noteId'),
            wav: any(named: 'wav'),
          ),
        );
      });

      test('fails when the user cannot be read', () {
        when(() => rondaApi.readUser(uid)).thenThrow(Exception('x'));

        expect(
          subject.readVoiceLine(uid),
          _fails(VoiceLineProblem.uploadFailed, code: 'read-user'),
        );
      });

      for (final (name, error, problem, code) in [
        (
          'refuses',
          const VoiceNoteRefusedException('unauthorized'),
          VoiceLineProblem.uploadRefused,
          'unauthorized',
        ),
        (
          'fails',
          const VoiceNoteUploadException('retry-limit-exceeded'),
          VoiceLineProblem.uploadFailed,
          'retry-limit-exceeded',
        ),
        ('breaks', Exception('x'), VoiceLineProblem.uploadFailed, null),
      ]) {
        test('says when the upload $name', () {
          when(
            () => rondaApi.uploadVoiceNote(
              uid: any(named: 'uid'),
              noteId: any(named: 'noteId'),
              wav: any(named: 'wav'),
            ),
          ).thenThrow(error);

          expect(subject.readVoiceLine(uid), _fails(problem, code: code));
        });
      }

      test('says when nothing could be understood', () {
        when(() => cuadernoApi.readLine(path))
            .thenThrow(const UnreadableVoiceNoteException());

        expect(
          subject.readVoiceLine(uid),
          _fails(VoiceLineProblem.notUnderstood),
        );
      });

      test('deletes a note the callable may not have reached', () async {
        when(() => cuadernoApi.readLine(path)).thenThrow(Exception('x'));

        await expectLater(
          subject.readVoiceLine(uid),
          _fails(VoiceLineProblem.readFailed),
        );
        verify(() => rondaApi.deleteVoiceNote(path)).called(1);
      });

      test('still fails with read when that delete fails too', () async {
        when(() => cuadernoApi.readLine(path)).thenThrow(Exception('x'));
        when(() => rondaApi.deleteVoiceNote(path)).thenThrow(Exception('y'));

        await expectLater(
          subject.readVoiceLine(uid),
          _fails(VoiceLineProblem.readFailed),
        );
      });
    });

    group('makePostcard', () {
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

      test('returns the postcard the callable drew', () async {
        when(() => cuadernoApi.makePostcard(any()))
            .thenAnswer((_) async => jpeg);

        expect(await subject.makePostcard(['uno']), equals(Postcard(jpeg)));
      });

      test('says when there was nothing to draw', () {
        when(() => cuadernoApi.makePostcard(any()))
            .thenThrow(const NothingToDrawException());

        expect(
          subject.makePostcard(['uno']),
          throwsA(isA<NothingToDrawFailure>()),
        );
      });

      test('says when it could not be drawn', () {
        when(() => cuadernoApi.makePostcard(any())).thenThrow(Exception('x'));

        expect(
          subject.makePostcard(['uno']),
          throwsA(isA<MakePostcardFailure>()),
        );
      });
    });

    group('sharePostcard', () {
      final postcard = Postcard(Uint8List.fromList([1, 2, 3]));

      test('opens the share sheet with the JPEG', () async {
        when(
          () => shareSheet.shareFile(
            any(),
            fileName: any(named: 'fileName'),
            mimeType: any(named: 'mimeType'),
            title: any(named: 'title'),
          ),
        ).thenAnswer((_) async => true);

        expect(await subject.sharePostcard(postcard, title: 'Postal'), isTrue);
        verify(
          () => shareSheet.shareFile(
            postcard.image,
            fileName: CuadernoRepository.fileName,
            mimeType: 'image/jpeg',
            title: 'Postal',
          ),
        ).called(1);
      });

      test('says when the sheet cannot open', () {
        when(
          () => shareSheet.shareFile(
            any(),
            fileName: any(named: 'fileName'),
            mimeType: any(named: 'mimeType'),
            title: any(named: 'title'),
          ),
        ).thenThrow(Exception('x'));

        expect(
          subject.sharePostcard(postcard),
          throwsA(isA<SharePostcardFailure>()),
        );
      });
    });

    test('a VoiceLineFailure reads as its problem and code', () {
      expect(
        const VoiceLineFailure(
          VoiceLineProblem.uploadFailed,
          code: 'x',
        ).toString(),
        equals('VoiceLineFailure(VoiceLineProblem.uploadFailed/x)'),
      );
      expect(
        const VoiceLineFailure(VoiceLineProblem.readFailed).toString(),
        equals('VoiceLineFailure(VoiceLineProblem.readFailed)'),
      );
    });
  });
}

/// Throws a [VoiceLineFailure] with [problem] (and [code] when given).
Matcher _fails(VoiceLineProblem problem, {String? code}) => throwsA(
  isA<VoiceLineFailure>()
      .having((failure) => failure.problem, 'problem', problem)
      .having((failure) => failure.code, 'code', code),
);
