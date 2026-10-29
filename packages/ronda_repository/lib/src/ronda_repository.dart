import 'package:firebase_core/firebase_core.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:rxdart/rxdart.dart';

/// {@template ronda_repository}
/// Rondas and the admin's proposals.
///
/// It turns `proposals/{id}` into [Proposal]s and the callables' errors into
/// [ProposalsFailure]s. Only the admin gets past either: for everyone else
/// the reason is [ProposalsFailureReason.forbidden].
///
/// For a member it follows their ronda's week as one [ThisWeek] and records
/// their answer; its failures are [RsvpFailure]s.
/// {@endtemplate}
class RondaRepository {
  /// {@macro ronda_repository}
  const new({required this._proposalsApi, required this._rondasApi});

  final ProposalsApi _proposalsApi;
  final RondasApi _rondasApi;

  /// The job that sends the weekly RSVP push.
  static const rsvpPushJob = 'rsvp_push';

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

  /// [uid]'s ronda and its upcoming meeting, now and on every change;
  /// `null` while they are in no ronda. The stream errors with an
  /// [RsvpFailure].
  Stream<ThisWeek?> watchThisWeek(String uid) => _rondasApi
      .watchRondaIds(uid)
      .map((ids) => ids.isEmpty ? null : (ids.toList()..sort()).first)
      .distinct()
      .switchMap(
        (rondaId) => rondaId == null
            ? Stream<ThisWeek?>.value(null)
            : Rx.combineLatest4(
                _rondasApi.watchRonda(rondaId),
                _rondasApi.watchMember(rondaId, uid),
                _rondasApi.watchWeekView(rondaId),
                _rondasApi.watchAnswer(rondaId, uid),
                _thisWeek,
              ),
      )
      .handleError(
        (Object error) => throw const RsvpFailure(RsvpFailureReason.other),
        test: (error) => error is Exception,
      );

  static ThisWeek? _thisWeek(
    RondaDocument? ronda,
    MemberDocument? member,
    WeekViewDocument? view,
    AnswerDocument? answer,
  ) {
    if (ronda == null || member == null) return null;
    return ThisWeek(
      rondaId: ronda.id,
      pretextId: ronda.pretext,
      barrioId: ronda.barrio,
      slotDayId: ronda.slotDay,
      slotBandId: ronda.slotBand,
      placeName: ronda.placeName,
      myBrings: member.brings,
      pausedUntil: member.state == 'paused'
          ? DateTime.tryParse(member.pausedUntil ?? '')
          : null,
      week: view?.week,
      date: view == null ? null : DateTime.tryParse(view.date),
      myAnswer: switch (answer) {
        AnswerDocument(:final week, answer: 'yes') when week == view?.week =>
          RsvpAnswer.yes,
        AnswerDocument(:final week, answer: 'no') when week == view?.week =>
          RsvpAnswer.no,
        _ => null,
      },
      going: [
        for (final person in view?.going ?? const <GoingDocument>[])
          GoingNeighbour(
            uid: person.uid,
            firstName: person.firstName,
            brings: person.brings,
          ),
      ],
      noCount: view?.noCount,
      unansweredCount: view?.unansweredCount,
    );
  }

  /// Records [answer] for ronda [rondaId]'s upcoming meeting. [week], when
  /// given, must still be that meeting's; [pause] (with
  /// [RsvpAnswer.no]) pauses the member for two weeks.
  ///
  /// Throws an [RsvpFailure].
  Future<void> answerRsvp({
    required String rondaId,
    required RsvpAnswer answer,
    String? week,
    bool pause = false,
  }) => _rsvpGuard(
    () => _rondasApi.answerRsvp(
      rondaId: rondaId,
      answer: answer.name,
      week: week,
      pauseWeeks: pause ? 2 : null,
    ),
  );

  /// Sends this week's RSVP push to every ronda now, ahead of its lead
  /// time (never twice in a week, never at night). Admin only.
  ///
  /// Throws an [RsvpFailure].
  Future<RsvpPushResult> sendRsvpNow() => _rsvpGuard(() async {
    final counts = await _rondasApi.runJob(rsvpPushJob, force: true);
    return RsvpPushResult(
      pushed: counts['pushed'] ?? 0,
      messages: counts['messages'] ?? 0,
      already: counts['already'] ?? 0,
      held: counts['held'] ?? 0,
    );
  });

  Future<T> _rsvpGuard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FirebaseException catch (error) {
      throw RsvpFailure(switch (error.code) {
        'permission-denied' || 'unauthenticated' => RsvpFailureReason.forbidden,
        'failed-precondition' => RsvpFailureReason.passed,
        _ => RsvpFailureReason.other,
      });
    } on Exception {
      throw const RsvpFailure(RsvpFailureReason.other);
    }
  }

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
