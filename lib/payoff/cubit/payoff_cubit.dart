import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'payoff_state.dart';

/// "Esto es lo que hay para vos": what the answers held on this phone find
/// in Cerca tuyo's public counts for their barrio, before sign-in.
///
/// It shows demand only, never seats: how many neighbours already signed up
/// for the person's pretexts, at their slots when the counts say so.
/// Nothing yet lets a new sign-up take a seat in an existing ronda, and the
/// solver can still split or trim a group.
class PayoffCubit extends Cubit<PayoffState> {
  new({required this._profileRepository, required this._rondaRepository})
    : super(const PayoffState());

  final ProfileRepository _profileRepository;
  final RondaRepository _rondaRepository;

  /// Reads the held answers, then their barrio's counts. Without held
  /// answers the state is [PayoffStatus.noAnswers]; without the counts
  /// (offline, an error) it is [PayoffStatus.unavailable].
  ///
  /// The button works while it reads, so the screen may be gone by the time
  /// the counts arrive: then nothing is emitted.
  Future<void> load() async {
    final answers = await _profileRepository.heldAnswers();
    if (answers == null) {
      _emitOpen(const PayoffState(status: PayoffStatus.noAnswers));
      return;
    }
    try {
      final cerca = await _rondaRepository.cerca(answers.barrio.id);
      _emitOpen(
        PayoffState(
          status: PayoffStatus.ready,
          barrio: answers.barrio,
          demand: demandFor(answers, cerca),
        ),
      );
    } on CercaFailure {
      _emitOpen(
        PayoffState(status: PayoffStatus.unavailable, barrio: answers.barrio),
      );
    }
  }

  void _emitOpen(PayoffState state) {
    if (!isClosed) emit(state);
  }

  /// The demand lines for [answers] in [cerca], in the pretexts' order.
  ///
  /// For each pretext the person picked: one line per slot of theirs with
  /// a count above zero, or, when no slot has one, the pretext's count at
  /// any slot. A count of zero is never shown.
  static List<PayoffDemand> demandFor(Profile answers, Cerca cerca) => [
    for (final pretext in Pretext.values)
      if (answers.pretexts.contains(pretext))
        ..._pretextDemand(pretext, answers.slots, cerca),
  ];

  static List<PayoffDemand> _pretextDemand(
    Pretext pretext,
    Set<Slot> slots,
    Cerca cerca,
  ) {
    final bySlot = [
      for (final day in SlotDay.values)
        for (final band in SlotBand.values)
          if (slots.contains(Slot(day, band)))
            if (_count(cerca.bySlot, pretext, Slot(day, band).id)
                case final count when count > 0)
              PayoffDemand(
                pretext: pretext,
                slot: Slot(day, band),
                count: count,
              ),
    ];
    if (bySlot.isNotEmpty) return bySlot;
    final count = _count(cerca.byPretext, pretext, null);
    return [if (count > 0) PayoffDemand(pretext: pretext, count: count)];
  }

  /// The largest count for [pretext] at [slotId] (`null`: any slot). Rondas
  /// of one pretext and slot share their count, so the largest is it.
  static int _count(
    List<CercaWaiting> counts,
    Pretext pretext,
    String? slotId,
  ) => counts
      .where((c) => c.pretextId == pretext.id && c.slotId == slotId)
      .fold(0, (largest, c) => c.count > largest ? c.count : largest);
}
