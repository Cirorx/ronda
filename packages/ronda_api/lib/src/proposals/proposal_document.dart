import 'package:cloud_firestore/cloud_firestore.dart';

/// {@template proposal_document}
/// One `proposals/{id}` document, in its wire shape: the solver's groups
/// waiting for the admin, as `functions/proposals.py` writes them.
/// {@endtemplate}
class const ProposalDocument({
  /// The document id.
  required final String id,

  /// `pending`, `approved` or `superseded` (a newer proposal replaced it).
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

  /// The people in [unseated] by first name, barrio and slots; empty on a
  /// proposal written before the field existed.
  final List<UnseatedPersonDocument> unseatedPeople = const [],

  /// Once approved, the ronda each group became, in group order; empty
  /// while pending.
  final List<String> rondaIds = const [],

  /// Whether the `auto_form` job wrote it, so it approves itself at
  /// [approveAt] unless something stops it.
  final bool auto = false,

  /// When an [auto] proposal approves itself; `null` on a manual one.
  final DateTime? approveAt,

  /// Whether the admin stopped an [auto] proposal (Frenar): it waits for
  /// a manual approval.
  final bool stopped = false,

  /// Why an [auto] proposal didn't approve itself (`stopped`, `setup`,
  /// `report`, `avoid`, `seated`, `removed`); `null` while nothing blocks it.
  final String? autoBlocked,
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
        unseatedPeople: [
          for (final person in _list(id, json['unseatedPeople']))
            UnseatedPersonDocument.fromJson(id, person),
        ],
        rondaIds: [
          for (final rondaId in _list(id, json['rondaIds']))
            if (rondaId is String) rondaId else throw _shape(id),
        ],
        auto: switch (json['auto']) {
          null => false,
          final bool auto => auto,
          _ => throw _shape(id),
        },
        approveAt: switch (json['approveAt']) {
          null => null,
          final Timestamp at => at.toDate(),
          _ => throw _shape(id),
        },
        stopped: json['stoppedAt'] != null,
        autoBlocked: switch (json['autoBlocked']) {
          null => null,
          final String why => why,
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

  /// The place, hour and hosts the organiser chose for an auto proposal;
  /// `null` on a manual one, or when neither the agent nor code could.
  final ProposedSetupDocument? setup,
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
        setup: switch (json['setup']) {
          null => null,
          final Object setup => ProposedSetupDocument.fromJson(
            proposalId,
            setup,
          ),
        },
      );
    }
    throw _shape(proposalId);
  }
}

/// {@template proposed_setup_document}
/// A group's `setup`: where, when and who opens, as `functions/auto_setup.py`
/// writes it.
/// {@endtemplate}
class const ProposedSetupDocument({
  /// The public place's name, with its article ("la plaza del barrio").
  required final String placeName,

  /// The hour, `HH:MM`, inside the slot's band.
  required final String hour,

  /// Who opens, by first name.
  required final String anfitrionName,

  /// Who closes, by first name.
  required final String colaName,

  /// Why, in one es-419 line: the agent's, or code's fixed rule.
  required final String reason,

  /// `agent` or `code`: who chose it.
  required final String by,
}) {
  /// {@macro proposed_setup_document}
  this;

  /// Reads the `setup` of a group of proposal [proposalId].
  factory fromJson(String proposalId, Object? json) {
    if (json case {
      'place': {'name': final String placeName},
      'hour': final String hour,
      'anfitrionName': final String anfitrionName,
      'colaName': final String colaName,
      'reason': final String reason,
      'by': final String by,
    }) {
      return ProposedSetupDocument(
        placeName: placeName,
        hour: hour,
        anfitrionName: anfitrionName,
        colaName: colaName,
        reason: reason,
        by: by,
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

/// {@template unseated_person_document}
/// One entry of a proposal's `unseatedPeople`: someone it leaves without a
/// ronda, as the admin needs to place them by hand.
/// {@endtemplate}
class const UnseatedPersonDocument({
  /// Their uid.
  required final String uid,

  /// Their first name.
  required final String firstName,

  /// Their barrio id.
  required final String barrio,

  /// The slot ids they picked (`sat-afternoon`).
  required final List<String> slots,

  /// The pretext ids they picked.
  required final List<String> pretexts,
}) {
  /// {@macro unseated_person_document}
  this;

  /// Reads one entry of `unseatedPeople` of proposal [proposalId].
  factory fromJson(String proposalId, Object? json) {
    if (json case {
      'uid': final String uid,
      'firstName': final String firstName,
      'barrio': final String barrio,
      'slots': final List<Object?> slots,
      'pretexts': final List<Object?> pretexts,
    }) {
      return UnseatedPersonDocument(
        uid: uid,
        firstName: firstName,
        barrio: barrio,
        slots: _strings(proposalId, slots),
        pretexts: _strings(proposalId, pretexts),
      );
    }
    throw _shape(proposalId);
  }
}

/// An optional list field: empty when missing.
List<Object?> _list(String id, Object? value) => switch (value) {
  null => const [],
  final List<Object?> list => list,
  _ => throw _shape(id),
};

List<String> _strings(String id, List<Object?> values) => [
  for (final value in values)
    if (value is String) value else throw _shape(id),
];

FormatException _shape(String id) =>
    FormatException('proposals/$id does not have the proposal shape');
