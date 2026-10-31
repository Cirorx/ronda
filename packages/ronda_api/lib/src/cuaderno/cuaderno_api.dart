import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:ronda_api/src/ronda_api_exceptions.dart';

/// {@template cuaderno_api}
/// The two callables behind "El cuaderno del barrio": `read_line` turns a
/// short voice note already uploaded to `audio/{uid}/{noteId}.wav` into the
/// words it says, and `make_postcard` draws the week's postcard from the
/// lines it is given.
///
/// **It has no Firestore and no Storage client.** The entries never leave the
/// phone except as the payload of [makePostcard], which stores nothing: the
/// lines go up in the call and the image comes back in the answer.
/// [functions] must be built with
/// `FirebaseFunctions.instanceFor(region: RondaApi.region)`.
/// {@endtemplate}
class const CuadernoApi({
  /// The callables' client, in Ronda's region.
  required final FirebaseFunctions functions,
}) {
  /// {@macro cuaderno_api}
  this;

  /// The callable that transcribes a short voice note.
  static const readLineCallable = 'read_line';

  /// The callable that draws the week's postcard.
  static const makePostcardCallable = 'make_postcard';

  /// How long the app waits for `read_line`: one Voice Transcribe call.
  static const readLineTimeout = Duration(seconds: 90);

  /// How long the app waits for the postcard: Spark 1.3, then Muse Image,
  /// plus a cold start.
  static const makePostcardTimeout = Duration(seconds: 120);

  /// Calls `read_line` on the voice note at [path] and returns what it says.
  /// The callable deletes the note before it answers.
  ///
  /// Throws an [UnreadableVoiceNoteException] when the callable couldn't read
  /// the note (too short, silent, not a WAV); any other failure passes
  /// through.
  Future<String> readLine(String path) async {
    try {
      final result = await functions
          .httpsCallable(
            readLineCallable,
            options: HttpsCallableOptions(timeout: readLineTimeout),
          )
          .call<Object?>({'path': path});
      return switch (result.data) {
        {'text': final String text} when text.trim().isNotEmpty => text.trim(),
        _ => throw const UnreadableVoiceNoteException(),
      };
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'invalid-argument') {
        throw const UnreadableVoiceNoteException();
      }
      rethrow;
    }
  }

  /// Calls `make_postcard` with [lines] and returns the postcard as JPEG
  /// bytes. Nothing is stored on the server.
  ///
  /// Throws a [NothingToDrawException] when the lines hold nothing a
  /// postcard can show; any other failure passes through.
  Future<Uint8List> makePostcard(List<String> lines) async {
    try {
      final result = await functions
          .httpsCallable(
            makePostcardCallable,
            options: HttpsCallableOptions(timeout: makePostcardTimeout),
          )
          .call<Object?>({'lines': lines});
      return switch (result.data) {
        {'image': final String image} => base64Decode(image),
        _ => throw const FormatException('make_postcard returned no image'),
      };
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition') {
        throw const NothingToDrawException();
      }
      rethrow;
    }
  }
}
