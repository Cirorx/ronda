import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:error_reporter/src/models/models.dart';

/// {@template client_error_log}
/// The web error log as the admin reads it: `client_errors`, newest first.
/// The rules let only the admin claim read it.
/// {@endtemplate}
class const ClientErrorLog({
  /// Firestore, built in bootstrap.
  required final FirebaseFirestore firestore,
}) {
  /// {@macro client_error_log}
  this;

  /// The collection `report_client_error` writes.
  static const collection = 'client_errors';

  /// How many reports `/admin/errores` reads.
  static const defaultLimit = 300;

  /// The newest [limit] reports, as they land. A refusal comes out as
  /// [ClientErrorLogFailure].
  Stream<List<ClientError>> watchRecent({int limit = defaultLimit}) => firestore
      .collection(collection)
      .orderBy('at', descending: true)
      .limit(limit)
      .snapshots()
      .transform(failuresAsClientErrorLogFailure())
      .map((snapshot) => [for (final doc in snapshot.docs) _error(doc)]);

  static ClientError _error(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    String text(String key) => switch (data[key]) {
      final String value => value,
      _ => '',
    };
    return ClientError(
      id: doc.id,
      platform: text('platform'),
      appVersion: text('appVersion'),
      build: text('build'),
      flavor: text('flavor'),
      screen: text('screen'),
      step: text('step'),
      code: text('code'),
      message: text('message'),
      stack: text('stack'),
      fatal: data['fatal'] == true,
      at: switch (data['at']) {
        final Timestamp at => at.toDate(),
        _ => DateTime.fromMillisecondsSinceEpoch(0),
      },
    );
  }
}

/// Turns a stream's errors into [ClientErrorLogFailure]s: `forbidden` when
/// the rules refused the read, `other` for anything else.
StreamTransformer<T, T> failuresAsClientErrorLogFailure<T>() =>
    StreamTransformer.fromHandlers(
      handleError: (error, stackTrace, sink) => sink.addError(
        ClientErrorLogFailure(
          error is FirebaseException && error.code == 'permission-denied'
              ? ClientErrorLogFailureReason.forbidden
              : ClientErrorLogFailureReason.other,
        ),
        stackTrace,
      ),
    );
