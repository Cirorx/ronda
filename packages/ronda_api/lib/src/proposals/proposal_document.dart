import 'package:cloud_firestore/cloud_firestore.dart';

/// {@template proposal_document}
/// One `proposals/{id}` document, in its wire shape: the solver's groups
/// waiting for the admin, as `functions/proposals.py` writes them.
/// {@endtemplate}
class const ProposalDocument({
  /// The document id.
  required final String id,

  /// `pending` or `approved`.
  required final String status,

  /// One entry per proposed ronda.
  required final List<ProposedGroupDocument> groups,

  /// The uids the solver could not seat.
  required final List<String> unseated,

  /// When the solver ran.
  required final DateTime createdAt,

  /// The es-419 sentence on why the next-best grouping lost, or `null` when
  /// nobody could be seated.
  final String? rejectedReason,
}) {
  /// {@macro proposal_document}
  this;

  /// Reads the document [id] from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(String id, Map<String, Object?> json) {
    if (json case {
      'status': final String status,
      'groups': final List<Object?> groups,
      'unseated': final List<Object?> unseated,
      'createdAt': final Timestamp createdAt,
      'rejectedAlternative': final Map<Object?, Object?>? alternative,
    }) {
      return ProposalDocument(
        id: id,
        status: status,
        groups: [
          for (final group in groups) ProposedGroupDocument.fromJson(id, group),
        ],
        unseated: [
          for (final uid in unseated)
            if (uid is String) uid else throw _shape(id),
        ],
        createdAt: createdAt.toDate(),
        rejectedReason: switch (alternative) {
          null => null,
          {'reason': final String reason} => reason,
          _ => throw _shape(id),
        },
      );
    }
    throw _shape(id);
  }
}

/// {@template proposed_group_document}
/// One group of a `proposals/{id}` document.
/// {@endtemplate}
class const ProposedGroupDocument({
  /// The seat id, `{barrio}_{pretext}_{slot}`.
  required final String seatId,

  /// The barrio id.
  required final String barrio,

  /// The pretext id.
  required final String pretext,

  /// The slot id (`sat-afternoon`).
  required final String slot,

  /// Who the solver put in it.
  required final List<ProposedMemberDocument> members,
}) {
  /// {@macro proposed_group_document}
  this;

  /// Reads one entry of the `groups` of proposal [proposalId].
  factory fromJson(String proposalId, Object? json) {
    if (json case {
      'id': final String seatId,
      'barrio': final String barrio,
      'pretext': final String pretext,
      'slot': final String slot,
      'members': final List<Object?> members,
    }) {
      return ProposedGroupDocument(
        seatId: seatId,
        barrio: barrio,
        pretext: pretext,
        slot: slot,
        members: [
          for (final member in members)
            ProposedMemberDocument.fromJson(proposalId, member),
        ],
      );
    }
    throw _shape(proposalId);
  }
}

/// {@template proposed_member_document}
/// One member of a proposed group: what the admin sees, never more.
/// {@endtemplate}
class const ProposedMemberDocument({
  /// The member's uid.
  required final String uid,

  /// Their first name.
  required final String firstName,

  /// Their age band id (`60-69`).
  required final String ageBand,

  /// Blocks between their barrio's centroid and the ronda's.
  required final double distanceBlocks,

  /// Whether their +1 is in the same group; `null` when they have no +1
  /// who signed up.
  final bool? plusOneInGroup,
}) {
  /// {@macro proposed_member_document}
  this;

  /// Reads one entry of a group's `members` of proposal [proposalId].
  factory fromJson(String proposalId, Object? json) {
    if (json case {
      'uid': final String uid,
      'firstName': final String firstName,
      'ageBand': final String ageBand,
      'distanceBlocks': final num distanceBlocks,
    }) {
      return ProposedMemberDocument(
        uid: uid,
        firstName: firstName,
        ageBand: ageBand,
        distanceBlocks: distanceBlocks.toDouble(),
        plusOneInGroup: switch (json['plusOneInGroup']) {
          final bool together => together,
          null => null,
          _ => throw _shape(proposalId),
        },
      );
    }
    throw _shape(proposalId);
  }
}

FormatException _shape(String id) =>
    FormatException('proposals/$id does not have the proposal shape');
