import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cuaderno_repository/src/cuaderno_failures.dart';
import 'package:cuaderno_repository/src/models/models.dart';
import 'package:device_store/device_store.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:share_sheet/share_sheet.dart';
import 'package:voice_recorder/voice_recorder.dart';

/// {@template cuaderno_repository}
/// El cuaderno del barrio: a private log of one line a day about what the
/// person noticed, and the weekly postcard drawn from it.
///
/// **The entries live only on the phone**, in [DeviceStore] under
/// `cuaderno.{uid}`, like needs. Reading, writing, choosing the line to
/// bring and deleting the cuaderno never touch the network: the only things
/// that leave are
/// - a short voice note ([readVoiceLine]), uploaded to `audio/{uid}/…`,
///   read into words by `read_line` and deleted by it (or by this
///   repository when it never got to) once read, as onboarding's is; and
/// - the lines of one week, as the payload of [makePostcard], which stores
///   nothing: the postcard comes back in the answer and only the phone's
///   share sheet keeps it.
///
/// Nothing leaves before `users/{uid}.terms` exists.
/// {@endtemplate}
class CuadernoRepository {
  /// {@macro cuaderno_repository}
  new({
    required this._deviceStore,
    required this._voiceRecorder,
    required this._rondaApi,
    required this._cuadernoApi,
    required this._shareSheet,
    String Function()? newNoteId,
  }) : _newNoteId = newNoteId ?? _randomNoteId;

  final DeviceStore _deviceStore;
  final VoiceRecorder _voiceRecorder;
  final RondaApi _rondaApi;
  final CuadernoApi _cuadernoApi;
  final ShareSheet _shareSheet;
  final String Function() _newNoteId;
  final _changes = StreamController<void>.broadcast();

  /// The file name a shared postcard gets.
  static const fileName = 'postal-del-barrio.jpg';

  /// The size of a RIFF/WAVE header with no samples after it.
  static const _wavHeaderBytes = 44;

  static String _randomNoteId() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  /// The device-store key that holds [uid]'s cuaderno, as one JSON value.
  static String storageKey(String uid) => 'cuaderno.$uid';

  /// Fires after the cuaderno changes on this phone: a line saved or
  /// deleted, another chosen to bring, or the cuaderno deleted.
  Stream<void> get changes => _changes.stream;

  /// [uid]'s cuaderno as the phone holds it; [Cuaderno.empty] when there is
  /// nothing saved or what is saved can't be read.
  Future<Cuaderno> read(String uid) async {
    final stored = await _deviceStore.read(storageKey(uid));
    if (stored == null) return Cuaderno.empty;
    try {
      return _decode(jsonDecode(stored));
    } on FormatException {
      return Cuaderno.empty;
    }
  }

  /// Writes the line for [day], replacing the one already there: a day has
  /// one line. [text] is made one line and cut at
  /// [CuadernoEntry.maxLength]; an empty one is not saved.
  ///
  /// Returns the cuaderno after it.
  Future<Cuaderno> saveEntry(
    String uid, {
    required DateTime day,
    required String text,
  }) async {
    final line = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .join(' ');
    final cuaderno = await read(uid);
    if (line.isEmpty) return cuaderno;
    final entry = CuadernoEntry(
      day: _midnight(day),
      text: line.length > CuadernoEntry.maxLength
          ? line.substring(0, CuadernoEntry.maxLength)
          : line,
    );
    return await _write(
      uid,
      Cuaderno(
        entries: [
          for (final other in cuaderno.entries)
            if (other.key != entry.key) other,
          entry,
        ]..sort((a, b) => b.key.compareTo(a.key)),
        bringDay: cuaderno.bringDay,
      ),
    );
  }

  /// Deletes the line for [day], and with it the choice to bring it.
  Future<Cuaderno> deleteEntry(String uid, DateTime day) async {
    final cuaderno = await read(uid);
    final key = CuadernoEntry.dayKey(day);
    return await _write(
      uid,
      Cuaderno(
        entries: [
          for (final entry in cuaderno.entries)
            if (entry.key != key) entry,
        ],
        bringDay: switch (cuaderno.bringDay) {
          final bring? when CuadernoEntry.dayKey(bring) != key => bring,
          _ => null,
        },
      ),
    );
  }

  /// Chooses the line of [day] to bring to the meeting; `null` chooses
  /// none. Choosing a day with no line chooses none.
  Future<Cuaderno> bring(String uid, DateTime? day) async {
    final cuaderno = await read(uid);
    return await _write(
      uid,
      Cuaderno(
        entries: cuaderno.entries,
        bringDay: day != null && cuaderno.on(day) != null
            ? _midnight(day)
            : null,
      ),
    );
  }

  /// Deletes [uid]'s whole cuaderno from this phone.
  Future<void> clear(String uid) async {
    await _deviceStore.delete(storageKey(uid));
    _changes.add(null);
  }

  Future<Cuaderno> _write(String uid, Cuaderno cuaderno) async {
    await _deviceStore.write(
      storageKey(uid),
      jsonEncode({
        'entries': [
          for (final entry in cuaderno.entries)
            {'day': entry.key, 'text': entry.text},
        ],
        'bring': ?switch (cuaderno.bringDay) {
          final day? => CuadernoEntry.dayKey(day),
          null => null,
        },
      }),
    );
    _changes.add(null);
    return cuaderno;
  }

  static DateTime _midnight(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  static DateTime? _parseDay(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    return DateTime(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
  }

  static Cuaderno _decode(Object? json) {
    if (json is! Map<Object?, Object?>) return Cuaderno.empty;
    final raw = json['entries'];
    if (raw is! List<Object?>) return Cuaderno.empty;
    final entries = <CuadernoEntry>[];
    for (final item in raw) {
      if (item case {'day': final String day, 'text': final String text}) {
        final parsed = _parseDay(day);
        if (parsed != null && text.isNotEmpty) {
          entries.add(CuadernoEntry(day: parsed, text: text));
        }
      }
    }
    entries.sort((a, b) => b.key.compareTo(a.key));
    return Cuaderno(entries: entries, bringDay: _parseDay(json['bring']));
  }

  /// Starts a voice note, asking for the microphone the first time.
  ///
  /// Throws a [VoiceLineFailure] when there is none to use, it may not be
  /// used, or the recorder fails.
  Future<void> startVoiceNote() async {
    final bool allowed;
    final bool present;
    try {
      allowed = await _voiceRecorder.hasPermission();
      // A browser with no microphone answers like one that was refused.
      present = allowed || await _voiceRecorder.hasMicrophone();
    } on Exception {
      throw const VoiceLineFailure(VoiceLineProblem.recorderFailed);
    }
    if (!present) throw const VoiceLineFailure(VoiceLineProblem.noMicrophone);
    if (!allowed) {
      throw const VoiceLineFailure(VoiceLineProblem.microphoneDenied);
    }
    try {
      await _voiceRecorder.start();
    } on Exception {
      throw const VoiceLineFailure(VoiceLineProblem.recorderFailed);
    }
  }

  /// How loud the microphone is while a note records, from 0 (silence) to
  /// 1. Only levels; never the audio.
  Stream<double> voiceLevels() => _voiceRecorder.levels();

  /// Stops and throws away the note being recorded, if any.
  Future<void> discardVoiceNote() async {
    try {
      await _voiceRecorder.cancel();
    } on Exception {
      // Nothing was recording; there is nothing to throw away.
    }
  }

  /// Stops the note and returns the words [uid] said in it, to be read and
  /// kept or not: nothing is written to the cuaderno here.
  ///
  /// Throws a [VoiceLineFailure] saying what went wrong. The note is
  /// uploaded only once `users/{uid}.terms` exists; `read_line` deletes it
  /// once read, and when it never got to, this repository does.
  Future<String> readVoiceLine(String uid) async {
    final Uint8List? wav;
    try {
      wav = await _voiceRecorder.stop();
    } on Exception {
      throw const VoiceLineFailure(VoiceLineProblem.recorderFailed);
    }
    // A WAV header alone (44 bytes) is a note with no sound in it.
    if (wav == null || wav.length <= _wavHeaderBytes) {
      throw const VoiceLineFailure(VoiceLineProblem.recorderFailed);
    }

    final UserDocument? user;
    try {
      user = await _rondaApi.readUser(uid);
    } on Exception {
      throw const VoiceLineFailure(
        VoiceLineProblem.uploadFailed,
        code: 'read-user',
      );
    }
    if (user?.terms == null) {
      throw const VoiceLineFailure(VoiceLineProblem.termsMissing);
    }

    final String path;
    try {
      path = await _rondaApi.uploadVoiceNote(
        uid: uid,
        noteId: _newNoteId(),
        wav: wav,
      );
    } on VoiceNoteRefusedException catch (error) {
      throw VoiceLineFailure(VoiceLineProblem.uploadRefused, code: error.code);
    } on VoiceNoteUploadException catch (error) {
      throw VoiceLineFailure(VoiceLineProblem.uploadFailed, code: error.code);
    } on Exception {
      throw const VoiceLineFailure(VoiceLineProblem.uploadFailed);
    }

    try {
      return await _cuadernoApi.readLine(path);
    } on UnreadableVoiceNoteException {
      throw const VoiceLineFailure(VoiceLineProblem.notUnderstood);
    } on Exception {
      await _deleteUnread(path);
      throw const VoiceLineFailure(VoiceLineProblem.readFailed);
    }
  }

  /// Draws the postcard from [lines], the week's lines and only those.
  /// They go up in the call and are stored nowhere.
  ///
  /// Throws a [NothingToDrawFailure] when they hold nothing a postcard can
  /// show and a [MakePostcardFailure] for anything else.
  Future<Postcard> makePostcard(List<String> lines) async {
    try {
      return Postcard(await _cuadernoApi.makePostcard(lines));
    } on NothingToDrawException {
      throw const NothingToDrawFailure();
    } on Exception {
      throw const MakePostcardFailure();
    }
  }

  /// Opens the share sheet with [postcard], titled [title]: where the
  /// person saves it to the phone. Returns whether they picked somewhere.
  ///
  /// Throws a [SharePostcardFailure] when the sheet can't open.
  Future<bool> sharePostcard(Postcard postcard, {String? title}) async {
    try {
      return await _shareSheet.shareFile(
        postcard.image,
        fileName: fileName,
        mimeType: 'image/jpeg',
        title: title,
      );
    } on Exception {
      throw const SharePostcardFailure();
    }
  }

  /// Deletes a note the callable may not have reached. A note it did read
  /// is already gone, so a failure here is expected and the bucket's 1-day
  /// lifecycle rule is the backstop.
  Future<void> _deleteUnread(String path) async {
    try {
      await _rondaApi.deleteVoiceNote(path);
    } on Exception {
      // Already deleted, or unreachable: the lifecycle rule removes it.
    }
  }
}
