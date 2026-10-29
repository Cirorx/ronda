import 'package:firebase_core/firebase_core.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:ronda_repository/ronda_repository.dart';

/// {@template ronda_repository}
/// Rondas and the admin's proposals.
///
/// It turns `proposals/{id}` into [Proposal]s and the callables' errors into
/// [ProposalsFailure]s. Only the admin gets past either: for everyone else
/// the reason is [ProposalsFailureReason.forbidden].
/// {@endtemplate}
class RondaRepository {
  /// {@macro ronda_repository}
  const new({required this._proposalsApi});

  final ProposalsApi _proposalsApi;

  static const _forbiddenCodes = {'permission-denied', 'unauthenticated'};

  /// The newest proposal now and on every change; `null` while there is
  /// none. The stream errors with a [ProposalsFailure].
  Stream<Proposal?> watchLatestProposal() => _proposalsApi
      .watchLatestProposal()
      .map((document) => document?.toProposal())
      .handleError(
        (Object error) => throw _failure(error),
        test: (error) => error is Exception,
      );

  /// Runs the solver on the current sign-ups; returns the new proposal's id.
  ///
  /// Throws a [ProposalsFailure].
  Future<String> proposeGroups() => _guard(_proposalsApi.proposeGroups);

  /// Approves proposal [id], which writes its rondas.
  ///
  /// Throws a [ProposalsFailure].
  Future<void> approveProposal(String id) =>
      _guard(() => _proposalsApi.approveProposal(id));

  /// Takes back the approval of proposal [id]: its rondas are deleted and
  /// it is pending again.
  ///
  /// Throws a [ProposalsFailure].
  Future<void> undoApproval(String id) =>
      _guard(() => _proposalsApi.undoApproval(id));

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on Exception catch (error) {
      throw _failure(error);
    }
  }

  static ProposalsFailure _failure(Object error) => ProposalsFailure(
    error is FirebaseException && _forbiddenCodes.contains(error.code)
        ? ProposalsFailureReason.forbidden
        : ProposalsFailureReason.other,
  );
}

extension on ProposalDocument {
  Proposal toProposal() => Proposal(
    id: id,
    status: status == 'approved'
        ? ProposalStatus.approved
        : ProposalStatus.pending,
    rondas: [
      for (final group in groups)
        ProposedRonda(
          seatId: group.seatId,
          barrioId: group.barrio,
          pretextId: group.pretext,
          slotId: group.slot,
          members: [
            for (final member in group.members)
              ProposedMember(
                uid: member.uid,
                firstName: member.firstName,
                ageBandId: member.ageBand,
                distanceBlocks: member.distanceBlocks,
                plusOneInGroup: member.plusOneInGroup,
              ),
          ],
        ),
    ],
    unseatedCount: unseated.length,
    createdAt: createdAt,
    rejectedReason: rejectedReason,
  );
}
