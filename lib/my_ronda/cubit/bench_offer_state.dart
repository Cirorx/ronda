part of 'bench_offer_cubit.dart';

/// Whether the offer card has anything to show.
enum BenchOfferCardStatus {
  /// Reading.
  loading,

  /// No offer matters now: no card.
  none,

  /// [BenchOfferState.offer] is the offer to show.
  ready,

  /// The offers couldn't be read.
  failure,
}

final class const BenchOfferState({
  final BenchOfferCardStatus status = BenchOfferCardStatus.loading,
  final BenchOffer? offer,

  /// An answer is on its way to the server.
  final bool saving = false,

  /// The last answer didn't reach the server.
  final bool saveFailed = false,

  /// The server said the offer had already ended.
  final bool over = false,
}) extends Equatable {
  BenchOfferState copyWith({bool? saving, bool? saveFailed, bool? over}) =>
      BenchOfferState(
        status: status,
        offer: offer,
        saving: saving ?? this.saving,
        saveFailed: saveFailed ?? this.saveFailed,
        over: over ?? this.over,
      );

  @override
  List<Object?> get props => [status, offer, saving, saveFailed, over];
}
