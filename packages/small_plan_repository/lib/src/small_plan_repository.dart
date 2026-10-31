import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:calendar_client/calendar_client.dart';
import 'package:device_store/device_store.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:small_plan_repository/src/models/models.dart';
import 'package:small_plan_repository/src/small_plan_failure.dart';
import 'package:voice_recorder/voice_recorder.dart';

/// {@template small_plan_repository}
/// Algo chico esta semana: one small plan a week, with a day, a time and a
/// place.
///
/// - The three suggestions and the shaping of what a member says (typed, or
///   a voice note that is uploaded, read and deleted) go through
///   [SmallPlansApi], which keeps nothing.
/// - The plan itself is kept on the phone only, in [DeviceStore], under the
///   member's uid, like needs: the server never learns who set a plan or who
///   did it. Nothing older than last week is kept, and there is no tally.
/// - The calendar is the phone's own ([CalendarClient]), so Ronda sends no
///   reminder of its own.
///
/// Nothing is sent before `users/{uid}.terms` exists.
/// {@endtemplate}
class SmallPlanRepository {
  /// {@macro small_plan_repository}
  new({
    required this._deviceStore,
    required this._voiceRecorder,
    required this._rondaApi,
    required this._smallPlansApi,
    required this._calendarClient,
    DateTime Function()? now,
    String Function()? newNoteId,
  }) : _now = now ?? DateTime.now,
       _newNoteId = newNoteId ?? _randomNoteId;

  final DeviceStore _deviceStore;
  final VoiceRecorder _voiceRecorder;
  final RondaApi _rondaApi;
  final SmallPlansApi _smallPlansApi;
  final CalendarClient _calendarClient;
  final DateTime Function() _now;
  final String Function() _newNoteId;

  /// The size of a RIFF/WAVE header with no samples after it.
  static const _wavHeaderBytes = 44;

  /// How long each kind of plan lasts in the calendar.
  static Duration lengthOf(SmallPlanKind kind) => switch (kind) {
    SmallPlanKind.noPhone => const Duration(hours: 3),
    SmallPlanKind.feria => const Duration(hours: 2),
    _ => const Duration(hours: 1),
  };

  /// The device-store key of [uid]'s plan.
  static String planKey(String uid) => 'smallPlan.$uid';

  /// The device-store key of the week [uid] put the offer off.
  static String skippedKey(String uid) => 'smallPlan.$uid.skipped';

  static String _randomNoteId() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  // --- What Mi ronda shows ----------------------------------------------

  /// What Mi ronda shows of Algo chico today.
  ///
  /// This week's plan (or one for a later day), else last week's, asked
  /// about once; a plan older than that is deleted. With none, the offer,
  /// unless the member put it off for this week.
  ///
  /// Throws a [SmallPlanFailure] when the phone can't read what it kept.
  Future<SmallPlanCard> current(String uid) async {
    final SmallPlan? plan;
    final String? skipped;
    try {
      plan = await _readPlan(uid);
      skipped = await _deviceStore.read(skippedKey(uid));
    } on Exception {
      throw const SmallPlanFailure(SmallPlanFailureKind.storageFailed);
    }
    final thisWeek = _monday(_now());
    if (plan != null) {
      final weeksAhead = _weeksBetween(thisWeek, _monday(plan.at));
      if (weeksAhead >= 0) return SmallPlanSet(plan);
      if (weeksAhead == -1) return SmallPlanFollowUp(plan);
      await _forget(uid);
    }
    return skipped == _dayId(thisWeek)
        ? const SmallPlanNothing()
        : const SmallPlanOffer();
  }

  Future<SmallPlan?> _readPlan(String uid) async {
    final stored = await _deviceStore.read(planKey(uid));
    if (stored == null) return null;
    try {
      return SmallPlan.fromJson(jsonDecode(stored));
    } on FormatException {
      // A value this app can't read is a plan it doesn't have.
      return null;
    }
  }

  Future<void> _forget(String uid) async {
    try {
      await _deviceStore.delete(planKey(uid));
    } on Exception {
      throw const SmallPlanFailure(SmallPlanFailureKind.storageFailed);
    }
  }

  /// Keeps [plan] as [uid]'s plan, replacing the one there was.
  Future<void> save(String uid, SmallPlan plan) async {
    try {
      await _deviceStore.write(planKey(uid), jsonEncode(plan.toJson()));
    } on Exception {
      throw const SmallPlanFailure(SmallPlanFailureKind.storageFailed);
    }
  }

  /// The answer to "¿Saliste a caminar el martes?": both answers are the
  /// same here. The plan is deleted and nothing about it is kept.
  Future<void> answerFollowUp(String uid) => _forget(uid);

  /// "Esta semana no": the offer stays away until next week.
  Future<void> skipThisWeek(String uid) async {
    try {
      await _deviceStore.write(skippedKey(uid), _dayId(_monday(_now())));
    } on Exception {
      throw const SmallPlanFailure(SmallPlanFailureKind.storageFailed);
    }
  }

  static DateTime _monday(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day - (day.weekday - 1));

  static int _weeksBetween(DateTime from, DateTime to) =>
      to.difference(from).inDays ~/ 7;

  static String _dayId(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  // --- Choosing -----------------------------------------------------------

  /// The three suggestions for this week.
  ///
  /// Throws a [SmallPlanFailure] ([SmallPlanFailureKind.suggestFailed]) when
  /// they couldn't be had.
  Future<List<SmallPlanSuggestion>> suggestions() async {
    try {
      final documents = await _smallPlansApi.suggest();
      return [
        for (final document in documents)
          SmallPlanSuggestion.fromDocument(document),
      ];
    } on Exception {
      throw const SmallPlanFailure(SmallPlanFailureKind.suggestFailed);
    }
  }

  /// Shapes what the member typed into a plan, or says why it was dropped.
  ///
  /// Throws a [SmallPlanFailure]: [SmallPlanFailureKind.termsMissing] before
  /// anything is sent, [SmallPlanFailureKind.notUnderstood] when there was
  /// nothing to read, [SmallPlanFailureKind.readFailed] otherwise.
  Future<SmallPlanReading> shapeText(String uid, String text) async {
    await _requireTerms(uid);
    return await _shape(text: text);
  }

  Future<void> _requireTerms(String uid) async {
    final UserDocument? user;
    try {
      user = await _rondaApi.readUser(uid);
    } on Exception {
      throw const SmallPlanFailure(
        SmallPlanFailureKind.uploadFailed,
        code: 'read-user',
      );
    }
    if (user?.terms == null) {
      throw const SmallPlanFailure(SmallPlanFailureKind.termsMissing);
    }
  }

  Future<SmallPlanReading> _shape({String? text, String? path}) async {
    final SmallPlanAnswer answer;
    try {
      answer = await _smallPlansApi.shape(text: text, path: path);
    } on UnreadableVoiceNoteException {
      throw const SmallPlanFailure(SmallPlanFailureKind.notUnderstood);
    } on Exception {
      if (path != null) await _deleteUnread(path);
      throw const SmallPlanFailure(SmallPlanFailureKind.readFailed);
    }
    return switch (answer) {
      SmallPlanShaped(:final plan) => _read(plan),
      SmallPlanRejected(:final reason) => SmallPlanDropped(
        PlanDropReason.fromName(reason),
      ),
    };
  }

  SmallPlanReading _read(ShapedSmallPlanDocument plan) {
    final DateTime at;
    try {
      at = SmallPlanSuggestion.parseWhen(plan.date, plan.time);
    } on FormatException {
      throw const SmallPlanFailure(SmallPlanFailureKind.readFailed);
    }
    return SmallPlanRead(
      plan: SmallPlan(
        kind: SmallPlanKind.fromName(plan.kind),
        at: at,
        place: plan.place,
        activity: plan.activity,
      ),
      moved: plan.moved,
      dry: plan.dry,
    );
  }

  // --- By voice -----------------------------------------------------------

  /// Starts a new voice note, asking for the microphone the first time.
  ///
  /// Throws a [SmallPlanFailure]: [SmallPlanFailureKind.noMicrophone],
  /// [SmallPlanFailureKind.microphoneDenied] or
  /// [SmallPlanFailureKind.recorderFailed].
  Future<void> startVoiceNote() async {
    final bool allowed;
    final bool present;
    try {
      allowed = await _voiceRecorder.hasPermission();
      // A browser with no microphone answers like one that was refused.
      present = allowed || await _voiceRecorder.hasMicrophone();
    } on Exception {
      throw const SmallPlanFailure(SmallPlanFailureKind.recorderFailed);
    }
    if (!present) {
      throw const SmallPlanFailure(SmallPlanFailureKind.noMicrophone);
    }
    if (!allowed) {
      throw const SmallPlanFailure(SmallPlanFailureKind.microphoneDenied);
    }
    try {
      await _voiceRecorder.start();
    } on Exception {
      throw const SmallPlanFailure(SmallPlanFailureKind.recorderFailed);
    }
  }

  /// How loud the microphone is while a note records, from 0 to 1. Only
  /// levels; never the audio.
  Stream<double> voiceLevels() => _voiceRecorder.levels();

  /// Stops and throws away the note being recorded, if any.
  Future<void> discardVoiceNote() async {
    try {
      await _voiceRecorder.cancel();
    } on Exception {
      // Nothing was recording; there is nothing to throw away.
    }
  }

  /// Stops the note and shapes what [uid] said in it into a plan.
  ///
  /// Throws a [SmallPlanFailure], each step with its own kind:
  /// [SmallPlanFailureKind.recorderFailed] when the recorder gave back no
  /// note, [SmallPlanFailureKind.termsMissing] before any upload,
  /// [SmallPlanFailureKind.uploadRefused] or
  /// [SmallPlanFailureKind.uploadFailed] when the note couldn't be sent,
  /// [SmallPlanFailureKind.notUnderstood] and
  /// [SmallPlanFailureKind.readFailed].
  Future<SmallPlanReading> shapeVoiceNote(String uid) async {
    final Uint8List? wav;
    try {
      wav = await _voiceRecorder.stop();
    } on Exception {
      throw const SmallPlanFailure(SmallPlanFailureKind.recorderFailed);
    }
    // A WAV header alone (44 bytes) is a note with no sound in it.
    if (wav == null || wav.length <= _wavHeaderBytes) {
      throw const SmallPlanFailure(SmallPlanFailureKind.recorderFailed);
    }
    await _requireTerms(uid);
    final String path;
    try {
      path = await _rondaApi.uploadVoiceNote(
        uid: uid,
        noteId: _newNoteId(),
        wav: wav,
      );
    } on VoiceNoteRefusedException catch (error) {
      throw SmallPlanFailure(
        SmallPlanFailureKind.uploadRefused,
        code: error.code,
      );
    } on VoiceNoteUploadException catch (error) {
      throw SmallPlanFailure(
        SmallPlanFailureKind.uploadFailed,
        code: error.code,
      );
    } on Exception {
      throw const SmallPlanFailure(SmallPlanFailureKind.uploadFailed);
    }
    return await _shape(path: path);
  }

  /// Deletes a note the callable may not have reached. A note it did read
  /// is already gone, so a failure here is expected and the 1-day lifecycle
  /// rule is the backstop.
  Future<void> _deleteUnread(String path) async {
    try {
      await _rondaApi.deleteVoiceNote(path);
    } on Exception {
      // Already deleted, or unreachable: the lifecycle rule removes it.
    }
  }

  // --- The calendar -------------------------------------------------------

  /// Puts [plan] in the phone's own calendar under [title] (the screen words
  /// it), or downloads an `.ics` file on web.
  ///
  /// Throws a [SmallPlanFailure] ([SmallPlanFailureKind.calendarUnavailable])
  /// when neither could be done.
  Future<CalendarOutcome> addToCalendar(
    SmallPlan plan, {
    required String title,
  }) async {
    try {
      return await _calendarClient.add(
        CalendarEvent(
          title: title,
          start: plan.at,
          end: plan.at.add(lengthOf(plan.kind)),
          location: plan.place,
        ),
      );
    } on CalendarUnavailableException {
      throw const SmallPlanFailure(SmallPlanFailureKind.calendarUnavailable);
    }
  }
}
