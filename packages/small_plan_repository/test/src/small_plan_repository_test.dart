import 'dart:convert';
import 'dart:typed_data';

import 'package:calendar_client/calendar_client.dart';
import 'package:device_store/device_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:small_plan_repository/small_plan_repository.dart';
import 'package:voice_recorder/voice_recorder.dart';

class _MockDeviceStore extends Mock implements DeviceStore;

class _MockVoiceRecorder extends Mock implements VoiceRecorder;

class _MockRondaApi extends Mock implements RondaApi;

class _MockSmallPlansApi extends Mock implements SmallPlansApi;

class _MockCalendarClient extends Mock implements CalendarClient;

void main() {
  group(SmallPlanRepository, () {
    late DeviceStore deviceStore;
    late VoiceRecorder voiceRecorder;
    late RondaApi rondaApi;
    late SmallPlansApi smallPlansApi;
    late CalendarClient calendarClient;
    late SmallPlanRepository subject;
    late Map<String, String> stored;

    const uid = 'demo-uid';
    const path = 'audio/demo-uid/note-1.wav';
    // Monday 2 November 2026, noon.
    final monday = DateTime(2026, 11, 2, 12);
    final withTerms = UserDocument(
      terms: TermsRecord(
        version: '2026-10-27',
        acceptedAt: DateTime(2026, 10, 28),
      ),
    );
    final tuesdayWalk = SmallPlan(
      kind: SmallPlanKind.walk,
      at: DateTime(2026, 11, 3, 19),
      place: 'la Rambla de Solymar',
    );
    const shaped = SmallPlanShaped(
      ShapedSmallPlanDocument(
        activity: 'Caminar 30 minutos por la rambla',
        date: '2026-11-03',
        time: '19:00',
        place: 'desde la parada 23',
        kind: 'walk',
        outdoor: true,
        dry: true,
        moved: true,
      ),
    );
    final wav = Uint8List(48);

    SmallPlanRepository build({DateTime? now, String Function()? newNoteId}) =>
        SmallPlanRepository(
          deviceStore: deviceStore,
          voiceRecorder: voiceRecorder,
          rondaApi: rondaApi,
          smallPlansApi: smallPlansApi,
          calendarClient: calendarClient,
          now: () => now ?? monday,
          newNoteId: newNoteId ?? () => 'note-1',
        );

    setUpAll(() {
      registerFallbackValue(Uint8List(0));
      registerFallbackValue(
        CalendarEvent(title: 'x', start: DateTime(2026), end: DateTime(2026)),
      );
    });

    setUp(() {
      stored = {};
      deviceStore = _MockDeviceStore();
      voiceRecorder = _MockVoiceRecorder();
      rondaApi = _MockRondaApi();
      smallPlansApi = _MockSmallPlansApi();
      calendarClient = _MockCalendarClient();
      subject = build();
      when(() => deviceStore.read(any())).thenAnswer(
        (invocation) async => stored[invocation.positionalArguments.first],
      );
      when(() => deviceStore.write(any(), any()))
          .thenAnswer((invocation) async {
            stored[invocation.positionalArguments.first as String] =
                invocation.positionalArguments.last as String;
          });
      when(() => deviceStore.delete(any())).thenAnswer((invocation) async {
        stored.remove(invocation.positionalArguments.first);
      });
      when(() => voiceRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => voiceRecorder.hasMicrophone()).thenAnswer((_) async => true);
      when(() => voiceRecorder.start()).thenAnswer((_) async {});
      when(() => voiceRecorder.cancel()).thenAnswer((_) async {});
      when(() => voiceRecorder.stop()).thenAnswer((_) async => wav);
      when(() => rondaApi.readUser(uid)).thenAnswer((_) async => withTerms);
      when(
        () => rondaApi.uploadVoiceNote(
          uid: any(named: 'uid'),
          noteId: any(named: 'noteId'),
          wav: any(named: 'wav'),
        ),
      ).thenAnswer((_) async => path);
      when(() => rondaApi.deleteVoiceNote(path)).thenAnswer((_) async {});
      when(
        () => smallPlansApi.shape(
          text: any(named: 'text'),
          path: any(named: 'path'),
        ),
      ).thenAnswer((_) async => shaped);
    });

    group('current', () {
      test('offers a plan when nothing is kept', () async {
        expect(await subject.current(uid), equals(const SmallPlanOffer()));
      });

      test("shows this week's plan, and one for a later week", () async {
        await subject.save(uid, tuesdayWalk);
        expect(await subject.current(uid), equals(SmallPlanSet(tuesdayWalk)));

        final later = build(now: DateTime(2026, 10, 28, 9));
        expect(await later.current(uid), equals(SmallPlanSet(tuesdayWalk)));
      });

      test("keeps the plan on the phone under the member's uid", () async {
        await subject.save(uid, tuesdayWalk);

        expect(stored.keys, equals([SmallPlanRepository.planKey(uid)]));
        expect(
          jsonDecode(stored[SmallPlanRepository.planKey(uid)]!),
          equals(tuesdayWalk.toJson()),
        );
        expect(await subject.current('someone-else'), isA<SmallPlanOffer>());
      });

      test("asks about last week's plan once the week has turned", () async {
        await subject.save(uid, tuesdayWalk);
        final nextWeek = build(now: DateTime(2026, 11, 9, 12));

        expect(
          await nextWeek.current(uid),
          equals(SmallPlanFollowUp(tuesdayWalk)),
        );
        // On the Sunday it is still this week.
        expect(
          await build(now: DateTime(2026, 11, 8, 23)).current(uid),
          isA<SmallPlanSet>(),
        );
      });

      test('keeps nothing older than last week', () async {
        await subject.save(uid, tuesdayWalk);
        final later = build(now: DateTime(2026, 11, 16, 12));

        expect(await later.current(uid), equals(const SmallPlanOffer()));
        expect(stored, isEmpty);
      });

      test('answering the follow-up deletes the plan, whichever the '
          'answer', () async {
        await subject.save(uid, tuesdayWalk);
        final nextWeek = build(now: DateTime(2026, 11, 9, 12));

        await nextWeek.answerFollowUp(uid);

        expect(stored, isEmpty);
        expect(await nextWeek.current(uid), equals(const SmallPlanOffer()));
      });

      test('"Esta semana no" hides the offer until next week', () async {
        await subject.skipThisWeek(uid);

        expect(await subject.current(uid), equals(const SmallPlanNothing()));
        expect(
          await build(now: DateTime(2026, 11, 9, 12)).current(uid),
          equals(const SmallPlanOffer()),
        );
      });

      test('a plan this week wins over "Esta semana no"', () async {
        await subject.skipThisWeek(uid);
        await subject.save(uid, tuesdayWalk);

        expect(await subject.current(uid), isA<SmallPlanSet>());
      });

      test('reads a stored value it cannot understand as no plan', () async {
        stored[SmallPlanRepository.planKey(uid)] = 'not json';

        expect(await subject.current(uid), equals(const SmallPlanOffer()));
      });

      test('throws when the phone cannot read what it kept', () {
        when(() => deviceStore.read(any())).thenThrow(Exception('keychain'));

        expect(
          subject.current(uid),
          throwsA(
            isA<SmallPlanFailure>().having(
              (failure) => failure.kind,
              'kind',
              SmallPlanFailureKind.storageFailed,
            ),
          ),
        );
      });

      test('throws when the phone cannot keep or forget', () async {
        when(() => deviceStore.write(any(), any()))
            .thenThrow(Exception('keychain'));
        when(() => deviceStore.delete(any())).thenThrow(Exception('keychain'));

        for (final call in [
          () => subject.save(uid, tuesdayWalk),
          () => subject.skipThisWeek(uid),
          () => subject.answerFollowUp(uid),
        ]) {
          expect(
            call,
            throwsA(
              isA<SmallPlanFailure>().having(
                (failure) => failure.kind,
                'kind',
                SmallPlanFailureKind.storageFailed,
              ),
            ),
          );
        }
      });

      test('throws when it cannot forget an old plan', () async {
        await subject.save(uid, tuesdayWalk);
        when(() => deviceStore.delete(any())).thenThrow(Exception('keychain'));

        expect(
          build(now: DateTime(2026, 11, 16, 12)).current(uid),
          throwsA(isA<SmallPlanFailure>()),
        );
      });
    });

    group('suggestions', () {
      test('reads the three suggestions into plans with a day', () async {
        when(() => smallPlansApi.suggest()).thenAnswer(
          (_) async => const [
            SmallPlanSuggestionDocument(
              id: 'walk-1',
              kind: 'walk',
              date: '2026-11-03',
              time: '18:00',
              outdoor: true,
              place: 'la Plaza',
              dry: true,
            ),
          ],
        );

        final suggestions = await subject.suggestions();

        expect(suggestions.single.at, equals(DateTime(2026, 11, 3, 18)));
        expect(suggestions.single.place, equals('la Plaza'));
      });

      test('throws when they could not be had', () {
        when(() => smallPlansApi.suggest()).thenThrow(Exception('down'));

        expect(
          subject.suggestions(),
          throwsA(
            isA<SmallPlanFailure>().having(
              (failure) => failure.kind,
              'kind',
              SmallPlanFailureKind.suggestFailed,
            ),
          ),
        );
      });

      test('throws when one has a day it cannot read', () {
        when(() => smallPlansApi.suggest()).thenAnswer(
          (_) async => const [
            SmallPlanSuggestionDocument(
              id: 'walk-1',
              kind: 'walk',
              date: 'nope',
              time: '18:00',
              outdoor: true,
            ),
          ],
        );

        expect(subject.suggestions(), throwsA(isA<SmallPlanFailure>()));
      });
    });

    group('shapeText', () {
      test('turns what was typed into a plan', () async {
        final reading = await subject.shapeText(uid, 'caminar por la rambla');

        expect(
          reading,
          equals(
            SmallPlanRead(
              plan: SmallPlan(
                kind: SmallPlanKind.walk,
                at: DateTime(2026, 11, 3, 19),
                place: 'desde la parada 23',
                activity: 'Caminar 30 minutos por la rambla',
              ),
              moved: true,
              dry: true,
            ),
          ),
        );
        verify(() => smallPlansApi.shape(text: 'caminar por la rambla'))
            .called(1);
      });

      test('says why a plan was dropped', () async {
        when(
          () => smallPlansApi.shape(
            text: any(named: 'text'),
            path: any(named: 'path'),
          ),
        ).thenAnswer((_) async => const SmallPlanRejected('health'));

        expect(
          await subject.shapeText(uid, 'x'),
          equals(const SmallPlanDropped(PlanDropReason.health)),
        );
      });

      test('sends nothing before the terms exist', () async {
        when(() => rondaApi.readUser(uid)).thenAnswer((_) async => null);

        await expectLater(
          subject.shapeText(uid, 'x'),
          throwsA(
            isA<SmallPlanFailure>().having(
              (failure) => failure.kind,
              'kind',
              SmallPlanFailureKind.termsMissing,
            ),
          ),
        );
        verifyNever(
          () => smallPlansApi.shape(
            text: any(named: 'text'),
            path: any(named: 'path'),
          ),
        );
      });

      test('throws when the terms could not be read', () {
        when(() => rondaApi.readUser(uid)).thenThrow(Exception('offline'));

        expect(
          subject.shapeText(uid, 'x'),
          throwsA(
            isA<SmallPlanFailure>().having(
              (failure) => failure.code,
              'code',
              'read-user',
            ),
          ),
        );
      });

      test('throws notUnderstood when there was nothing to read', () {
        when(
          () => smallPlansApi.shape(
            text: any(named: 'text'),
            path: any(named: 'path'),
          ),
        ).thenThrow(const UnreadableVoiceNoteException());

        expect(
          subject.shapeText(uid, ' '),
          throwsA(
            isA<SmallPlanFailure>().having(
              (failure) => failure.kind,
              'kind',
              SmallPlanFailureKind.notUnderstood,
            ),
          ),
        );
      });

      test('throws readFailed for any other failure', () {
        when(
          () => smallPlansApi.shape(
            text: any(named: 'text'),
            path: any(named: 'path'),
          ),
        ).thenThrow(Exception('down'));

        expect(
          subject.shapeText(uid, 'x'),
          throwsA(
            isA<SmallPlanFailure>().having(
              (failure) => failure.kind,
              'kind',
              SmallPlanFailureKind.readFailed,
            ),
          ),
        );
      });

      test('throws readFailed for a plan with a day it cannot read', () {
        when(
          () => smallPlansApi.shape(
            text: any(named: 'text'),
            path: any(named: 'path'),
          ),
        ).thenAnswer(
          (_) async => const SmallPlanShaped(
            ShapedSmallPlanDocument(
              activity: 'x',
              date: 'nope',
              time: '19:00',
              kind: 'walk',
              outdoor: true,
              moved: false,
            ),
          ),
        );

        expect(subject.shapeText(uid, 'x'), throwsA(isA<SmallPlanFailure>()));
      });
    });

    group('by voice', () {
      Matcher failure(SmallPlanFailureKind kind) =>
          throwsA(isA<SmallPlanFailure>().having((f) => f.kind, 'kind', kind));

      test('starts a note when the microphone may be used', () async {
        await subject.startVoiceNote();

        verify(() => voiceRecorder.start()).called(1);
      });

      test('says there is no microphone, or it was refused', () async {
        when(() => voiceRecorder.hasPermission())
            .thenAnswer((_) async => false);
        when(() => voiceRecorder.hasMicrophone())
            .thenAnswer((_) async => false);
        await expectLater(
          subject.startVoiceNote(),
          failure(SmallPlanFailureKind.noMicrophone),
        );

        when(() => voiceRecorder.hasMicrophone()).thenAnswer((_) async => true);
        await expectLater(
          subject.startVoiceNote(),
          failure(SmallPlanFailureKind.microphoneDenied),
        );
      });

      test('says the recorder failed when it cannot be asked or started', () {
        when(() => voiceRecorder.hasPermission()).thenThrow(Exception('x'));
        expect(
          subject.startVoiceNote(),
          failure(SmallPlanFailureKind.recorderFailed),
        );
      });

      test('says the recorder failed when it will not start', () {
        when(() => voiceRecorder.start()).thenThrow(Exception('x'));

        expect(
          subject.startVoiceNote(),
          failure(SmallPlanFailureKind.recorderFailed),
        );
      });

      test('passes the levels through', () {
        when(() => voiceRecorder.levels())
            .thenAnswer((_) => Stream.fromIterable([0.1, 0.5]));

        expect(subject.voiceLevels(), emitsInOrder([0.1, 0.5]));
      });

      test(
        'throws a note away, and forgives a recorder with nothing',
        () async {
          await subject.discardVoiceNote();
          when(() => voiceRecorder.cancel()).thenThrow(Exception('idle'));
          await subject.discardVoiceNote();

          verify(() => voiceRecorder.cancel()).called(2);
        },
      );

      test('uploads the note and shapes it into a plan', () async {
        final reading = await subject.shapeVoiceNote(uid);

        expect(reading, isA<SmallPlanRead>());
        verify(
          () => rondaApi.uploadVoiceNote(uid: uid, noteId: 'note-1', wav: wav),
        ).called(1);
        verify(() => smallPlansApi.shape(path: path)).called(1);
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
        final random = SmallPlanRepository(
          deviceStore: deviceStore,
          voiceRecorder: voiceRecorder,
          rondaApi: rondaApi,
          smallPlansApi: smallPlansApi,
          calendarClient: calendarClient,
        );

        await random.shapeVoiceNote(uid);
        await random.shapeVoiceNote(uid);

        expect(ids.first, matches(RegExp(r'^[0-9a-f]{32}$')));
        expect(ids.first, isNot(equals(ids.last)));
      });

      test(
        'fails when the recorder gives back no note, or only a header',
        () async {
          when(() => voiceRecorder.stop()).thenAnswer((_) async => null);
          await expectLater(
            subject.shapeVoiceNote(uid),
            failure(SmallPlanFailureKind.recorderFailed),
          );
          when(() => voiceRecorder.stop())
              .thenAnswer((_) async => Uint8List(44));
          await expectLater(
            subject.shapeVoiceNote(uid),
            failure(SmallPlanFailureKind.recorderFailed),
          );
          when(() => voiceRecorder.stop()).thenThrow(Exception('x'));
          await expectLater(
            subject.shapeVoiceNote(uid),
            failure(SmallPlanFailureKind.recorderFailed),
          );
        },
      );

      test('uploads nothing before the terms exist', () async {
        when(() => rondaApi.readUser(uid)).thenAnswer((_) async => null);

        await expectLater(
          subject.shapeVoiceNote(uid),
          failure(SmallPlanFailureKind.termsMissing),
        );
        verifyNever(
          () => rondaApi.uploadVoiceNote(
            uid: any(named: 'uid'),
            noteId: any(named: 'noteId'),
            wav: any(named: 'wav'),
          ),
        );
      });

      test('tells a refused upload from a failed one', () async {
        when(
          () => rondaApi.uploadVoiceNote(
            uid: any(named: 'uid'),
            noteId: any(named: 'noteId'),
            wav: any(named: 'wav'),
          ),
        ).thenThrow(const VoiceNoteRefusedException('unauthorized'));
        await expectLater(
          subject.shapeVoiceNote(uid),
          throwsA(
            isA<SmallPlanFailure>()
                .having(
                  (f) => f.kind,
                  'kind',
                  SmallPlanFailureKind.uploadRefused,
                )
                .having((f) => f.code, 'code', 'unauthorized'),
          ),
        );

        when(
          () => rondaApi.uploadVoiceNote(
            uid: any(named: 'uid'),
            noteId: any(named: 'noteId'),
            wav: any(named: 'wav'),
          ),
        ).thenThrow(const VoiceNoteUploadException('retry-limit-exceeded'));
        await expectLater(
          subject.shapeVoiceNote(uid),
          failure(SmallPlanFailureKind.uploadFailed),
        );

        when(
          () => rondaApi.uploadVoiceNote(
            uid: any(named: 'uid'),
            noteId: any(named: 'noteId'),
            wav: any(named: 'wav'),
          ),
        ).thenThrow(Exception('offline'));
        await expectLater(
          subject.shapeVoiceNote(uid),
          failure(SmallPlanFailureKind.uploadFailed),
        );
      });

      test('deletes a note the callable never read', () async {
        when(() => smallPlansApi.shape(path: any(named: 'path')))
            .thenThrow(Exception('down'));

        await expectLater(
          subject.shapeVoiceNote(uid),
          failure(SmallPlanFailureKind.readFailed),
        );
        verify(() => rondaApi.deleteVoiceNote(path)).called(1);
      });

      test('forgives a note that is already gone', () async {
        when(() => smallPlansApi.shape(path: any(named: 'path')))
            .thenThrow(Exception('down'));
        when(() => rondaApi.deleteVoiceNote(path)).thenThrow(Exception('gone'));

        await expectLater(
          subject.shapeVoiceNote(uid),
          failure(SmallPlanFailureKind.readFailed),
        );
      });

      test(
        'says nothing was understood, and the note is not deleted twice',
        () async {
          when(() => smallPlansApi.shape(path: any(named: 'path')))
              .thenThrow(const UnreadableVoiceNoteException());

          await expectLater(
            subject.shapeVoiceNote(uid),
            failure(SmallPlanFailureKind.notUnderstood),
          );
          verifyNever(() => rondaApi.deleteVoiceNote(path));
        },
      );
    });

    group('addToCalendar', () {
      test('adds an event for the plan with its place, for an hour', () async {
        when(() => calendarClient.add(any()))
            .thenAnswer((_) async => CalendarOutcome.opened);

        final outcome = await subject.addToCalendar(
          tuesdayWalk,
          title: 'Caminar',
        );

        expect(outcome, equals(CalendarOutcome.opened));
        final event =
            verify(() => calendarClient.add(captureAny())).captured.single
                as CalendarEvent;
        expect(event.title, equals('Caminar'));
        expect(event.start, equals(DateTime(2026, 11, 3, 19)));
        expect(event.end, equals(DateTime(2026, 11, 3, 20)));
        expect(event.location, equals('la Rambla de Solymar'));
      });

      test('lasts longer for an afternoon without the phone and the '
          'feria', () {
        expect(
          SmallPlanRepository.lengthOf(SmallPlanKind.noPhone),
          equals(const Duration(hours: 3)),
        );
        expect(
          SmallPlanRepository.lengthOf(SmallPlanKind.feria),
          equals(const Duration(hours: 2)),
        );
        expect(
          SmallPlanRepository.lengthOf(SmallPlanKind.other),
          equals(const Duration(hours: 1)),
        );
      });

      test('throws when the calendar is not available', () {
        when(() => calendarClient.add(any()))
            .thenThrow(const CalendarUnavailableException());

        expect(
          subject.addToCalendar(tuesdayWalk, title: 'Caminar'),
          throwsA(
            isA<SmallPlanFailure>().having(
              (failure) => failure.kind,
              'kind',
              SmallPlanFailureKind.calendarUnavailable,
            ),
          ),
        );
      });
    });
  });
}
