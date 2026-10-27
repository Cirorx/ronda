import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ronda_api/src/ronda_api.dart';
import 'package:ronda_api/src/seat_facts/seat_facts_document.dart';

/// Seat facts in, eligible seat ids out: the only Firestore paths the
/// phone's needs filter touches (`docs/ARCHITECTURE.md` § Thesis).
///
/// An extension so it sits in its own file beside the profile methods on
/// [RondaApi].
extension EligibleSeatsApi on RondaApi {
  /// The seat facts the server publishes, one document per seat id.
  static const seatFactsCollection = 'seat_facts';

  /// The subcollection of `users/{uid}` that members never read back.
  static const privateCollection = 'private';

  /// The document under [privateCollection] that holds the eligible ids.
  static const eligibleDocument = 'eligible';

  /// Every published seat.
  ///
  /// A document that doesn't have the seat shape is skipped: a seat whose
  /// facts can't be read can't be checked against needs, so it never passes.
  Future<List<SeatFactsDocument>> readSeatFacts() async {
    final snapshot = await firestore.collection(seatFactsCollection).get();
    return [for (final document in snapshot.docs) ?_tryRead(document)];
  }

  /// Replaces `users/{uid}/private/eligible` with [seatIds] and the server's
  /// time, and nothing else: the needs that chose them stay on the phone.
  Future<void> writeEligibleSeatIds({
    required String uid,
    required List<String> seatIds,
  }) => firestore
      .collection(RondaApi.usersCollection)
      .doc(uid)
      .collection(privateCollection)
      .doc(eligibleDocument)
      .set({'seatIds': seatIds, 'updatedAt': FieldValue.serverTimestamp()});

  static SeatFactsDocument? _tryRead(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    try {
      return SeatFactsDocument.fromJson(document.id, document.data());
    } on FormatException {
      return null;
    }
  }
}
