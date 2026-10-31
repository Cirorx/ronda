part of 'donde_queda_guess_cubit.dart';

/// Where the member's guess stands.
enum DondeQuedaGuessStatus {
  /// Reading the game and the photo.
  loading,

  /// The photo and the map, to drop the pin.
  ready,

  /// The pin is on its way.
  sending,

  /// The pin is in.
  done,

  /// Nothing to guess: the game closed, or the photo is the member's.
  closed,

  /// The game or the photo couldn't be read.
  failure,
}

/// The photo, the map and the pin.
final class const DondeQuedaGuessState({
  final DondeQuedaGuessStatus status = DondeQuedaGuessStatus.loading,

  /// This week's game, once read.
  final DondeQuedaGame? game,

  /// The photo, as JPEG bytes.
  final Uint8List? photo,

  /// Where the member dropped the pin.
  final MapPoint? pin,

  /// The last [Es acá] didn't go through.
  final bool sendFailed = false,
}) extends Equatable {
  /// A copy with the given fields changed.
  DondeQuedaGuessState copyWith({
    DondeQuedaGuessStatus? status,
    MapPoint? pin,
    bool? sendFailed,
  }) => DondeQuedaGuessState(
    status: status ?? this.status,
    game: game,
    photo: photo,
    pin: pin ?? this.pin,
    sendFailed: sendFailed ?? this.sendFailed,
  );

  @override
  List<Object?> get props => [status, game, photo, pin, sendFailed];
}
