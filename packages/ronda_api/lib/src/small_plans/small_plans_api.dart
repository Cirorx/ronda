import 'package:cloud_functions/cloud_functions.dart';
import 'package:ronda_api/src/ronda_api_exceptions.dart';
import 'package:ronda_api/src/small_plans/small_plan_documents.dart';

/// {@template small_plans_api}
/// Algo chico esta semana's two callables (`functions/small_plans.py`,
/// `functions/plan_suggestions.py`): three suggestions, and what a member
/// said or typed shaped into one dated plan.
///
/// Neither keeps anything on the server, and this keeps nothing on the
/// phone: the plan is held by `small_plan_repository`. A voice note is
/// uploaded with `RondaApi.uploadVoiceNote` and then read here by its path.
/// [functions] must be built with
/// `FirebaseFunctions.instanceFor(region: RondaApi.region)`.
/// {@endtemplate}
class const SmallPlansApi({
  /// The callables' client, in Ronda's region.
  required final FirebaseFunctions functions,
}) {
  /// {@macro small_plans_api}
  this;

  /// The callable that suggests three plans.
  static const suggestCallable = 'suggest_small_plans';

  /// The callable that shapes what the member said.
  static const shapeCallable = 'shape_small_plan';

  /// How long the app waits for the suggestions: the forecast, Muse Spark
  /// Open (which reasons first) and a cold start.
  static const suggestTimeout = Duration(seconds: 90);

  /// How long the app waits for a plan: Voice Transcribe, Spark 1.3 and the
  /// forecast, plus a cold start.
  static const shapeTimeout = Duration(seconds: 120);

  /// Three suggestions for this week.
  ///
  /// Throws a [FormatException] for an answer of another shape.
  Future<List<SmallPlanSuggestionDocument>> suggest() async {
    final result = await functions
        .httpsCallable(
          suggestCallable,
          options: HttpsCallableOptions(timeout: suggestTimeout),
        )
        .call<Object?>();
    return switch (result.data) {
      {'suggestions': final List<Object?> suggestions} => [
        for (final suggestion in suggestions)
          SmallPlanSuggestionDocument.fromJson(suggestion),
      ],
      _ => throw const FormatException('suggest_small_plans returned none'),
    };
  }

  /// Shapes the words in [text], or in the voice note at [path], into a plan.
  /// Pass one of them. The callable deletes the note before it answers.
  ///
  /// Throws an [UnreadableVoiceNoteException] when there was nothing to
  /// read, and passes any other failure through.
  Future<SmallPlanAnswer> shape({String? text, String? path}) async {
    try {
      final result = await functions
          .httpsCallable(
            shapeCallable,
            options: HttpsCallableOptions(timeout: shapeTimeout),
          )
          .call<Object?>({'text': ?text, 'path': ?path});
      return SmallPlanAnswer.fromJson(result.data);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'invalid-argument') {
        throw const UnreadableVoiceNoteException();
      }
      rethrow;
    }
  }
}
