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
///
/// For anyone, signed in or not, it reads a barrio's [Cerca] demand.
/// {@endtemplate}
class RondaRepository {
  /// {@macro ronda_repository}
  const new({
    required this._proposalsApi,
    required this._rondasApi,
    this._cercaTimeout = defaultCercaTimeout,
  });

  final ProposalsApi _proposalsApi;
  final RondasApi _rondasApi;
  final Duration _cercaTimeout;

  /// How long [cerca] waits for the counts before it gives up: offline, a
  /// read may otherwise wait for a connection that never comes.
  static const defaultCercaTimeout = Duration(seconds: 8);

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

  /// Who could be added to ronda [rondaId], and who is in it now. Admin
  /// only.
  ///
  /// Throws a [ProposalsFailure].
  Future<RondaCandidates> rondaCandidates(String rondaId) => _guard(() async {
    final document = await _proposalsApi.rondaCandidates(rondaId);
    return RondaCandidates(
      rondaId: document.rondaId,
      line: document.line,
      members: document.members,
      taken: document.taken,
      cap: document.cap,
      people: [
        for (final person in document.people)
          Candidate(
            uid: person.uid,
            firstName: person.firstName,
            ageBandId: person.ageBand,
            barrioId: person.barrio,
            slotIds: person.slots,
            warnings: _warnings(person.warnings),
            blocks: person.blocks,
            currentRondaId: person.rondaId,
            currentRondaLine: person.rondaLine,
          ),
      ],
    );
  });

  /// "Sumar a esta ronda": adds sign-up [uid] to ronda [rondaId] as an
  /// active member who hasn't answered this week; [move] takes them out of
  /// the ronda they are in. Admin only.
  ///
  /// Throws a [ProposalsFailure]: [ProposalsFailureReason.full] when no
  /// seat is left, [ProposalsFailureReason.alreadyIn] when they are in it.
  Future<AddedToRonda> addToRonda({
    required String rondaId,
    required String uid,
    bool move = false,
  }) => _guard(() async {
    final document = await _proposalsApi.addToRonda(
      rondaId: rondaId,
      uid: uid,
      move: move,
    );
    return AddedToRonda(
      rondaId: document.rondaId,
      uid: document.uid,
      warnings: _warnings(document.warnings),
      movedFrom: document.movedFrom,
    );
  });

  static List<CandidateWarning> _warnings(List<String> names) => [
    for (final name in names) ?CandidateWarning.values.asNameMap()[name],
  ];

  /// The pilot's numbers, counted now. Admin only.
  ///
  /// Throws a [ProposalsFailure].
  Future<PilotNumbers> pilotNumbers() => _guard(() async {
    final document = await _rondasApi.pilotNumbers();
    CountOf? countOf(CountOfDocument? value) =>
        value == null ? null : CountOf(value.count, value.of);
    return PilotNumbers(
      profiles: CountOf(document.profiles, document.signUps),
      seated: CountOf(document.seated, document.profiles),
      cameBack: countOf(document.cameBack),
      rondas: [
        for (final ronda in document.rondas)
          PilotRonda(
            rondaId: ronda.rondaId,
            line: ronda.line,
            members: CountOf(ronda.members, ronda.cap),
            cameBack: countOf(ronda.cameBack),
            seguimos: switch (ronda.seguimos) {
              null => null,
              final counts => PilotSeguimos(
                yes: CountOf(counts.yes, counts.asked),
                no: counts.no,
                unanswered: counts.unanswered,
              ),
            },
            weeks: [
              for (final week in ronda.weeks)
                PilotWeek(
                  week: week.week,
                  date: DateTime.tryParse(week.date ?? ''),
                  yes: CountOf(week.yes, week.members),
                  no: week.no,
                  unanswered: week.unanswered,
                  came: switch ((week.came, week.marked)) {
                    (final int came, final int marked) => CountOf(came, marked),
                    _ => null,
                  },
                ),
            ],
          ),
      ],
    );
  });

  /// Cerca tuyo's demand in [barrioId]; empty while the barrio has no counts
  /// yet.
  ///
  /// Throws a [CercaFailure] when the read fails or takes longer than the
  /// timeout ([defaultCercaTimeout] by default).
  Future<Cerca> cerca(String barrioId) async {
    final CercaDocument? document;
    try {
      document = await _rondasApi.readCerca(barrioId).timeout(_cercaTimeout);
    } on Exception {
      throw const CercaFailure();
    }
    return Cerca(
      barrioId: barrioId,
      bySlot: [
        for (final row in document?.slotWaiting ?? const <CercaSlotWaiting>[])
          CercaWaiting(
            pretextId: row.pretext,
            slotId: row.slot,
            count: row.count,
          ),
      ],
      byPretext: [
        for (final row
            in document?.pretextWaiting ?? const <CercaPretextWaiting>[])
          CercaWaiting(pretextId: row.pretext, count: row.count),
      ],
    );
  }

  /// [uid]'s ronda and its upcoming meeting, now and on every change;
  /// `null` while they are in no ronda. The stream errors with an
  /// [RsvpFailure].
  Stream<ThisWeek?> watchThisWeek(String uid) => _myRondaId(uid)
      .switchMap(
        (rondaId) => rondaId == null
            ? Stream<ThisWeek?>.value(null)
            : Rx.combineLatest5(
                _rondasApi.watchRonda(rondaId),
                _rondasApi.watchMember(rondaId, uid),
                _viewAndDespues(rondaId),
                _rondasApi.watchAnswer(rondaId, uid),
                _rondasApi.watchHandoffAsk(rondaId, uid),
                (ronda, member, week, answer, handoff) => _thisWeek(
                  ronda,
                  member,
                  week.$1,
                  answer,
                  despues: week.$2,
                  handoff: handoff,
                ),
              ),
      )
      .handleError(
        (Object error) => throw const RsvpFailure(RsvpFailureReason.other),
        test: (error) => error is Exception,
      );

  /// The id of the ronda [uid]'s phone follows: the first by id.
  Stream<String?> _myRondaId(String uid) => _rondasApi
      .watchRondaIds(uid)
      .map((ids) => ids.isEmpty ? null : (ids.toList()..sort()).first)
      .distinct();

  /// The week's view, and the después of the week it shows.
  Stream<(WeekViewDocument?, DespuesDocument?)> _viewAndDespues(
    String rondaId,
  ) => _rondasApi
      .watchWeekView(rondaId)
      .switchMap(
        (view) => view == null
            ? Stream.value((null, null))
            : _rondasApi
                  .watchDespues(rondaId, view.week)
                  .map((despues) => (view, despues)),
      );

  static ThisWeek? _thisWeek(
    RondaDocument? ronda,
    MemberDocument? member,
    WeekViewDocument? view,
    AnswerDocument? answer, {
    DespuesDocument? despues,
    HandoffAskDocument? handoff,
  }) {
    if (ronda == null || member == null) return null;
    return ThisWeek(
      rondaId: ronda.id,
      pretextId: ronda.pretext,
      barrioId: ronda.barrio,
      slotDayId: ronda.slotDay,
      slotBandId: ronda.slotBand,
      placeName: ronda.placeName,
      placeLandmark: ronda.placeLandmark,
      hour: ronda.slotHour,
      anfitrion: _hostOf(ronda.anfitrionUid, ronda.anfitrionName),
      cola: _hostOf(ronda.colaUid, ronda.colaName),
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
            guest: person.guest,
          ),
      ],
      noCount: view?.noCount,
      unansweredCount: view?.unansweredCount,
      hasLeft: member.state == 'left',
      turns: [
        for (final turn in ronda.turns)
          if (DateTime.tryParse('${turn.month}-01') case final month?)
            HostTurn(
              month: month,
              anfitrion: Host(
                uid: turn.anfitrionUid,
                firstName: turn.anfitrionName,
              ),
              cola: Host(uid: turn.colaUid, firstName: turn.colaName),
            ),
      ],
      opener: ronda.openerWeek != null && ronda.openerWeek == view?.week
          ? _hostOf(ronda.openerUid, ronda.openerName)
          : null,
      despues: switch (despues) {
        final despues? when despues.week == view?.week => _despues(despues),
        _ => null,
      },
      handoffAsk: switch (handoff) {
        HandoffAskDocument(:final week, status: 'open')
            when week == view?.week =>
          HandoffAsk(
            week: week,
            date: DateTime.tryParse(handoff.date) ?? DateTime(0),
            hour: handoff.hour,
            fromName: handoff.fromName.isEmpty ? null : handoff.fromName,
            reason: HandoffReason.values.asNameMap()[handoff.reason],
          ),
        _ => null,
      },
    );
  }

  static Despues? _despues(DespuesDocument despues) {
    final kind = DespuesKind.values.asNameMap()[despues.kind];
    final status = DespuesStatus.values.asNameMap()[despues.status];
    if (kind == null || status == null) return null;
    return Despues(
      kind: kind,
      status: status,
      setBy: Host(uid: despues.setByUid, firstName: despues.setByName),
      what: despues.what,
      where: despues.where,
      homeOf: _hostOf(despues.homeOfUid, despues.homeName),
      address: despues.address,
    );
  }

  static Host? _hostOf(String? uid, String? firstName) =>
      uid == null ? null : Host(uid: uid, firstName: firstName ?? '');

  /// [uid]'s own ¿seguimos? in their ronda, now and on every change; `null`
  /// until they are asked. The stream errors with an [RsvpFailure].
  Stream<Seguimos?> watchSeguimos(String uid) => _myRondaId(uid)
      .switchMap(
        (rondaId) => rondaId == null
            ? Stream<Seguimos?>.value(null)
            : Rx.combineLatest2(
                _rondasApi.watchRonda(rondaId),
                _rondasApi.watchSeguimos(rondaId, uid),
                _seguimos,
              ),
      )
      .handleError(
        (Object error) => throw const RsvpFailure(RsvpFailureReason.other),
        test: (error) => error is Exception,
      );

  static Seguimos? _seguimos(RondaDocument? ronda, SeguimosDocument? own) {
    if (ronda == null || own == null) return null;
    return Seguimos(
      rondaId: ronda.id,
      slotDayId: ronda.slotDay,
      open: own.status == 'open',
      myAnswer: SeguimosAnswer.values.asNameMap()[own.answer],
      outcome: SeguimosOutcome.values.asNameMap()[own.outcome],
      seasonEnd: DateTime.tryParse(ronda.seasonEnd ?? ''),
      alternatives: [
        for (final row in own.alternatives)
          if (DateTime.tryParse(row.next) case final next?)
            NearbyRonda(
              rondaId: row.rondaId,
              pretextId: row.pretext,
              barrioId: row.barrio,
              slotDayId: row.slotDay,
              slotBandId: row.slotBand,
              placesLeft: row.placesLeft,
              next: next,
            ),
      ],
      floor: own.floor,
      waitUntil: DateTime.tryParse(own.waitUntil ?? ''),
      waitStart: DateTime.tryParse(own.waitStart ?? ''),
      choice: SeguimosChoice.values.asNameMap()[own.choice],
    );
  }

  /// Records [answer] to ronda [rondaId]'s ¿seguimos? while it is open; it
  /// can change until the close.
  ///
  /// Throws an [RsvpFailure]: [RsvpFailureReason.passed] once it closed.
  Future<void> answerSeguimos({
    required String rondaId,
    required SeguimosAnswer answer,
  }) => _rsvpGuard(
    () => _rondasApi.answerSeguimos(rondaId: rondaId, answer: answer.name),
  );

  /// Records the member's [choice] after ronda [rondaId]'s ¿seguimos?
  /// closed below the floor.
  ///
  /// Throws an [RsvpFailure].
  Future<void> chooseAfterSeguimos({
    required String rondaId,
    required SeguimosChoice choice,
  }) => _rsvpGuard(
    () => _rondasApi.answerSeguimos(rondaId: rondaId, choice: choice.name),
  );

  /// The offers of freed seats made to [uid] that still matter: pending,
  /// or taken; newest meeting first. The stream errors with an
  /// [RsvpFailure].
  Stream<List<BenchOffer>> watchBenchOffers(String uid) => _rondasApi
      .watchOffers(uid)
      .map(
        (documents) =>
            [for (final document in documents) ?_benchOffer(document)]
              ..sort((a, b) => b.date.compareTo(a.date)),
      )
      .handleError(
        (Object error) => throw const RsvpFailure(RsvpFailureReason.other),
        test: (error) => error is Exception,
      );

  static BenchOffer? _benchOffer(BenchOfferDocument document) {
    final date = DateTime.tryParse(document.date);
    if (date == null) return null;
    return BenchOffer(
      offerId: document.id,
      rondaId: document.rondaId,
      date: date,
      pretextId: document.pretext,
      slotDayId: document.slotDay,
      slotBandId: document.slotBand,
      deadline: document.deadline,
      status: switch (document.status) {
        'pending' => BenchOfferStatus.pending,
        'taken' => BenchOfferStatus.taken,
        _ => BenchOfferStatus.over,
      },
      hour: document.hour,
      placeName: document.placeName,
      placeLandmark: document.placeLandmark,
    );
  }

  /// "Lo tomo" ([take]) or "Esta vez no" on offer [offerId].
  ///
  /// Throws an [RsvpFailure]: [RsvpFailureReason.passed] once the offer is
  /// over (its deadline passed, or the seat filled again).
  Future<void> answerBenchOffer({
    required String offerId,
    required bool take,
  }) => _rsvpGuard(
    () => _rondasApi.answerBenchOffer(offerId: offerId, take: take),
  );

  /// [uid]'s place on the waiting list nearest to filling, now and on every
  /// change; `null` while they wait on no list. The stream errors with an
  /// [RsvpFailure].
  Stream<Waiting?> watchWaiting(String uid) => _rondasApi
      .watchWaiting(uid)
      .map(_waiting)
      .handleError(
        (Object error) => throw const RsvpFailure(RsvpFailureReason.other),
        test: (error) => error is Exception,
      );

  static Waiting? _waiting(WaitingDocument? document) {
    if (document == null) return null;
    final deadline = DateTime.tryParse(document.deadline);
    final start = DateTime.tryParse(document.start);
    final slot = document.slot.split('-');
    if (deadline == null || start == null) return null;
    return Waiting(
      pretextId: document.pretext,
      barrioId: document.barrio,
      slotDayId: slot.first,
      slotBandId: slot.last,
      count: document.count,
      threshold: document.threshold,
      deadline: deadline,
      start: start,
      status:
          WaitingStatus.values.asNameMap()[document.status] ??
          WaitingStatus.open,
      nearby: switch (document.alternatives) {
        [final row, ...] when DateTime.tryParse(row.next) != null =>
          NearbyRonda(
            rondaId: row.rondaId,
            pretextId: row.pretext,
            barrioId: row.barrio,
            slotDayId: row.slotDay,
            slotBandId: row.slotBand,
            placesLeft: row.placesLeft,
            next: DateTime.parse(row.next),
          ),
        _ => null,
      },
      choice: WaitlistChoice.values.asNameMap()[document.choice],
    );
  }

  /// Records [choice] after the caller's waiting list didn't fill.
  ///
  /// Throws an [RsvpFailure]: [RsvpFailureReason.passed] when there is
  /// nothing to choose any more.
  Future<void> chooseAfterWaitlist(WaitlistChoice choice) =>
      _rsvpGuard(() => _rondasApi.answerWaitlist(choice.name));

  /// Every ronda's ¿seguimos? counts, now and on every change. Admin only:
  /// the stream errors with an [RsvpFailure], [RsvpFailureReason.forbidden]
  /// for anyone else.
  Stream<List<SeguimosCounts>> watchSeguimosCounts() => _rondasApi
      .watchSeguimosCounts()
      .map(
        (rows) => [
          for (final row in rows)
            SeguimosCounts(
              rondaId: row.rondaId,
              line: row.line,
              status:
                  SeguimosStatus.values.asNameMap()[row.status] ??
                  SeguimosStatus.open,
              yes: row.yes,
              no: row.no,
              unanswered: row.unanswered,
              join: row.join,
              wait: row.wait,
              seasonEnd: DateTime.tryParse(row.seasonEnd ?? ''),
            ),
        ],
      )
      .handleError(
        (Object error) => throw RsvpFailure(
          error is FirebaseException && _forbiddenCodes.contains(error.code)
              ? RsvpFailureReason.forbidden
              : RsvpFailureReason.other,
        ),
        test: (error) => error is Exception,
      );

  /// Every ronda that still meets, with its place, hour, hosts and members.
  /// Admin only.
  ///
  /// Throws a [HostsFailure].
  Future<List<RondaSetup>> rondaSetups() => _hostsGuard(() async {
    final rows = await _rondasApi.rondaSetups();
    return [
      for (final row in rows)
        RondaSetup(
          rondaId: row.rondaId,
          pretextId: row.pretext,
          barrioId: row.barrio,
          slotDayId: row.slotDay,
          slotBandId: row.slotBand,
          members: [
            for (final member in row.members)
              SetupMember(uid: member.uid, firstName: member.firstName),
          ],
          hour: row.hour,
          placeName: row.placeName,
          placeLandmark: row.placeLandmark,
          anfitrionUid: row.anfitrionUid,
          colaUid: row.colaUid,
          roll: switch (row.roll) {
            final roll? when DateTime.tryParse(roll.date) != null =>
              RollSummary(
                week: roll.week,
                date: DateTime.parse(roll.date),
                people: roll.people,
                marked: roll.marked,
              ),
            _ => null,
          },
          handoff: switch (row.handoff) {
            final handoff?
                when DateTime.tryParse(handoff.date) != null &&
                    HandoffStep.values.asNameMap()[handoff.step] != null =>
              HandoffSummary(
                date: DateTime.parse(handoff.date),
                step: HandoffStep.values.byName(handoff.step),
                fromName: handoff.fromName,
                takenName: handoff.takenName,
              ),
            _ => null,
          },
        ),
    ];
  });

  /// Sets ronda [rondaId]'s después for its upcoming meeting of [week]:
  /// [kind] with [what], and [where] for a public place, or [homeOfUid]
  /// (the caller when `null`) and [address] for a home. This week's hosts
  /// only.
  ///
  /// Throws a [HostsFailure]: [HostsFailureReason.notPublic] when the words
  /// aren't allowed (an address for a public place, money, an emoji).
  Future<void> setDespues({
    required String rondaId,
    required String week,
    required DespuesKind kind,
    String? what,
    String? where,
    String? homeOfUid,
    String? address,
  }) => _hostsGuard(
    () => _rondasApi.setDespues(
      rondaId: rondaId,
      week: week,
      kind: kind.name,
      what: what,
      where: where,
      homeOfUid: homeOfUid,
      address: address,
    ),
    refused: HostsFailureReason.notPublic,
  );

  /// Says whether the después of ronda [rondaId]'s meeting of [week] may be
  /// at the caller's home.
  ///
  /// Throws a [HostsFailure]: [HostsFailureReason.passed] once there is
  /// nothing to answer.
  Future<void> answerDespues({
    required String rondaId,
    required String week,
    required bool yes,
  }) => _hostsGuard(
    () => _rondasApi.answerDespues(rondaId: rondaId, week: week, yes: yes),
    refused: HostsFailureReason.passed,
  );

  /// "Sí, abro yo" ([yes]) or "Hoy no puedo" for ronda [rondaId]'s meeting
  /// of [week].
  ///
  /// Throws a [HostsFailure]: [HostsFailureReason.passed] once someone else
  /// opens it or the question closed.
  Future<void> answerHandoff({
    required String rondaId,
    required String week,
    required bool yes,
  }) => _hostsGuard(
    () => _rondasApi.answerHandoff(rondaId: rondaId, week: week, yes: yes),
    refused: HostsFailureReason.passed,
  );

  /// [uid]'s open buddy card in their ronda, now and on every change;
  /// `null` while there is none. The stream errors with a [HostsFailure].
  Stream<BuddyAsk?> watchBuddyAsk(String uid) => _myRondaId(uid)
      .switchMap(
        (rondaId) => rondaId == null
            ? Stream<BuddyAsk?>.value(null)
            : _rondasApi
                  .watchBuddyAsk(rondaId, uid)
                  .map(
                    (card) =>
                        card == null ||
                            card.status != 'open' ||
                            card.asks.isEmpty
                        ? null
                        : BuddyAsk(
                            rondaId: rondaId,
                            misses: [
                              for (final miss in card.asks)
                                BuddyMiss(
                                  firstName: miss.firstName,
                                  dayId: miss.day,
                                ),
                            ],
                          ),
                  ),
      )
      .handleError(
        (Object error) => throw _hostsFailure(error),
        test: (error) => error is Exception,
      );

  /// Closes [uid]'s buddy card in ronda [rondaId] ([Le escribo], [Ahora
  /// no]).
  ///
  /// Throws a [HostsFailure].
  Future<void> closeBuddyAsk({required String rondaId, required String uid}) =>
      _hostsGuard(() => _rondasApi.closeBuddyAsk(rondaId, uid));

  /// Whether it is time for the caller to choose a buddy in ronda
  /// [rondaId], who they could choose, and who they chose.
  ///
  /// Throws a [HostsFailure].
  Future<BuddyOptions> buddyOptions(String rondaId) => _hostsGuard(() async {
    final document = await _rondasApi.buddyOptions(rondaId);
    return BuddyOptions(
      due: document.due,
      chosen: document.chosen,
      choices: [
        for (final choice in document.choices)
          SetupMember(uid: choice.uid, firstName: choice.firstName),
      ],
      buddy: switch ((document.buddyUid, document.buddyName)) {
        (final uid?, final name) => SetupMember(
          uid: uid,
          firstName: name ?? '',
        ),
        _ => null,
      },
    );
  });

  /// Saves the caller's buddy in ronda [rondaId]: [buddyUid], or `null`
  /// for nobody ("Ahora no").
  ///
  /// Throws a [HostsFailure].
  Future<void> setBuddy({required String rondaId, String? buddyUid}) =>
      _hostsGuard(
        () => _rondasApi.setBuddy(rondaId: rondaId, buddyUid: buddyUid),
      );

  /// Sets ronda [rondaId]'s public place, hour and hosts at once; a `null`
  /// takes each one away. Admin only.
  ///
  /// Throws a [HostsFailure]: [HostsFailureReason.notPublic] when the
  /// place's words look like a home or an address.
  Future<void> setRondaSetup({
    required String rondaId,
    String? placeName,
    String? placeLandmark,
    String? hour,
    String? anfitrionUid,
    String? colaUid,
  }) => _hostsGuard(
    () => _rondasApi.setRondaSetup(
      rondaId: rondaId,
      placeName: placeName,
      placeLandmark: placeLandmark,
      hour: hour,
      anfitrionUid: anfitrionUid,
      colaUid: colaUid,
    ),
    refused: HostsFailureReason.notPublic,
  );

  /// Ronda [rondaId]'s "¿Quién vino hoy?" for [week], now and on every
  /// change; `null` until the attendance job writes it. Its hosts and the
  /// admin only: the stream errors with a [HostsFailure] for anyone else.
  Stream<AttendanceRoll?> watchRoll(String rondaId, String week) => _rondasApi
      .watchRoll(rondaId, week)
      .map(
        (roll) => roll == null
            ? null
            : AttendanceRoll(
                week: roll.week,
                date: DateTime.tryParse(roll.date) ?? DateTime(0),
                line: roll.line,
                people: [
                  for (final person in roll.people)
                    SetupMember(uid: person.uid, firstName: person.firstName),
                ],
                marks: roll.marks,
              ),
      )
      .handleError(
        (Object error) => throw _hostsFailure(error),
        test: (error) => error is Exception,
      );

  /// Records whether [uid] [came] to ronda [rondaId]'s meeting of [week].
  /// The ronda's hosts or the admin.
  ///
  /// Throws a [HostsFailure]: [HostsFailureReason.passed] once the meeting
  /// is too long ago.
  Future<void> recordAttendance({
    required String rondaId,
    required String week,
    required String uid,
    required bool came,
  }) => _hostsGuard(
    () => _rondasApi.recordAttendance(
      rondaId: rondaId,
      week: week,
      uid: uid,
      came: came,
    ),
    refused: HostsFailureReason.passed,
  );

  Future<T> _hostsGuard<T>(
    Future<T> Function() call, {
    HostsFailureReason refused = HostsFailureReason.other,
  }) async {
    try {
      return await call();
    } on Exception catch (error) {
      throw _hostsFailure(error, refused: refused);
    }
  }

  /// [refused] is what a `failed-precondition` means for the call: a place
  /// that isn't public when setting a ronda up, a meeting too long ago when
  /// recording.
  static HostsFailure _hostsFailure(
    Object error, {
    HostsFailureReason refused = HostsFailureReason.other,
  }) => HostsFailure(switch (error) {
    FirebaseException(code: 'permission-denied' || 'unauthenticated') =>
      HostsFailureReason.forbidden,
    FirebaseException(code: 'failed-precondition') => refused,
    _ => HostsFailureReason.other,
  });

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

  static ProposalsFailure _failure(Object error) =>
      ProposalsFailure(switch (error) {
        FirebaseException(:final code) when _forbiddenCodes.contains(code) =>
          ProposalsFailureReason.forbidden,
        FirebaseException(code: 'resource-exhausted') =>
          ProposalsFailureReason.full,
        FirebaseException(code: 'already-exists') =>
          ProposalsFailureReason.alreadyIn,
        _ => ProposalsFailureReason.other,
      });
}

extension on ProposalDocument {
  Proposal toProposal() => Proposal(
    id: id,
    status: status == 'approved'
        ? ProposalStatus.approved
        : ProposalStatus.pending,
    rondas: [
      for (final (index, group) in groups.indexed)
        ProposedRonda(
          seatId: group.seatId,
          barrioId: group.barrio,
          pretextId: group.pretext,
          slotId: group.slot,
          rondaId: index < rondaIds.length ? rondaIds[index] : null,
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
    unseated: [
      for (final person in unseatedPeople)
        UnseatedPerson(
          uid: person.uid,
          firstName: person.firstName,
          barrioId: person.barrio,
          slotIds: person.slots,
          pretextIds: person.pretexts,
        ),
    ],
    createdAt: createdAt,
    rejectedReason: rejectedReason,
  );
}
