import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'bench_offer_state.dart';

/// The offer of a freed seat on Mi ronda: follows [_uid]'s offers and shows
/// the one that matters now (a pending one before its deadline, else a taken
/// one until its meeting), and answers it with "Lo tomo" or "Esta vez no".
///
/// A failed answer leaves the card as it was, with
/// [BenchOfferState.saveFailed], or [BenchOfferState.over] when the server
/// said the offer had ended; nothing is held against the person either way.
class BenchOfferCubit extends Cubit<BenchOfferState> {
  new({
    required this._uid,
    required this._rondaRepository,
    this._now = DateTime.now,
  }) : super(const BenchOfferState());

  final String _uid;
  final RondaRepository _rondaRepository;
  final DateTime Function() _now;
  StreamSubscription<List<BenchOffer>>? _subscription;

  /// Follows the person's offers.
  void subscribe() {
    unawaited(_subscription?.cancel());
    emit(const BenchOfferState());
    _subscription = _rondaRepository
        .watchBenchOffers(_uid)
        .listen(
          (offers) {
            final offer = current(offers, _now());
            emit(
              BenchOfferState(
                status: offer == null
                    ? BenchOfferCardStatus.none
                    : BenchOfferCardStatus.ready,
                offer: offer,
                saving: state.saving,
              ),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            emit(const BenchOfferState(status: BenchOfferCardStatus.failure));
          },
        );
  }

  /// The offer the card shows at [now] from [offers] (newest meeting
  /// first): a pending one whose deadline hasn't passed, else a taken one
  /// whose meeting isn't over; `null` when none.
  static BenchOffer? current(List<BenchOffer> offers, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    for (final offer in offers) {
      if (offer.status == BenchOfferStatus.pending &&
          offer.deadline.isAfter(now)) {
        return offer;
      }
    }
    for (final offer in offers) {
      if (offer.status == BenchOfferStatus.taken &&
          !offer.date.isBefore(today)) {
        return offer;
      }
    }
    return null;
  }

  /// "Lo tomo".
  Future<void> takeTapped() => _answer(take: true);

  /// "Esta vez no".
  Future<void> passTapped() => _answer(take: false);

  Future<void> _answer({required bool take}) async {
    final offer = state.offer;
    if (offer == null || state.saving) return;
    emit(state.copyWith(saving: true, saveFailed: false, over: false));
    try {
      await _rondaRepository.answerBenchOffer(
        offerId: offer.offerId,
        take: take,
      );
    } on RsvpFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      if (isClosed) return;
      final over = error.reason == RsvpFailureReason.passed;
      emit(state.copyWith(saving: false, saveFailed: !over, over: over));
      return;
    }
    if (!isClosed) emit(state.copyWith(saving: false));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
