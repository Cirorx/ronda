import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ronda_api/src/proposals/proposal_document.dart';

/// {@template proposals_api}
/// The admin's side of forming rondas: reads `proposals/{id}` and calls the
/// `propose_groups` and `approve_proposal` callables.
///
/// Only an account with the admin claim gets anywhere: the rules refuse the
/// read and the callables refuse the call for everyone else.
/// [functions] must be built with
/// `FirebaseFunctions.instanceFor(region: RondaApi.region)`.
/// {@endtemplate}
class const ProposalsApi({
  /// The Firestore instance the proposals are read from.
  required final FirebaseFirestore firestore,

  /// The callables' client, in Ronda's region.
  required final FirebaseFunctions functions,
}) {
  /// {@macro proposals_api}
  this;

  /// The collection the solver's proposals are written to.
  static const proposalsCollection = 'proposals';

  /// The callable that solves the sign-ups into a new proposal.
  static const proposeGroupsCallable = 'propose_groups';

  /// The callable that approves a proposal, or takes an approval back.
  static const approveProposalCallable = 'approve_proposal';

  /// The newest proposal now and on every change; `null` while there is
  /// none.
  ///
  /// The stream errors with a [FirebaseException] when the rules refuse
  /// the read, and with a [FormatException] for a document of another
  /// shape.
  Stream<ProposalDocument?> watchLatestProposal() => firestore
      .collection(proposalsCollection)
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map(
        (snapshot) => switch (snapshot.docs) {
          [final document, ...] => ProposalDocument.fromJson(
            document.id,
            document.data(),
          ),
          [] => null,
        },
      );

  /// Runs the solver on the current sign-ups; returns the new proposal's id.
  ///
  /// Throws a [FirebaseFunctionsException] when the call fails.
  Future<String> proposeGroups() async {
    final result = await functions
        // The default 60 s timeout covers the 10 s solve and a cold start.
        .httpsCallable(proposeGroupsCallable)
        .call<Map<Object?, Object?>>();
    return switch (result.data) {
      {'proposalId': final String id} => id,
      _ => throw const FormatException('propose_groups returned no id'),
    };
  }

  /// Approves proposal [id]: the server writes its rondas.
  ///
  /// Throws a [FirebaseFunctionsException] when the call fails.
  Future<void> approveProposal(String id) => functions
      .httpsCallable(approveProposalCallable)
      .call<Object?>({'proposalId': id});

  /// Takes back the approval of proposal [id]: the server deletes the
  /// rondas it wrote and the proposal is pending again.
  ///
  /// Throws a [FirebaseFunctionsException] when the call fails.
  Future<void> undoApproval(String id) => functions
      .httpsCallable(approveProposalCallable)
      .call<Object?>({'proposalId': id, 'undo': true});
}
