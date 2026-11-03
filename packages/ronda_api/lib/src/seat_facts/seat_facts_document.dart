/// {@template seat_facts_document}
/// One `seat_facts` document, in its wire shape: what the server publishes
/// about a place so the phone can match it against needs it never sends.
///
/// The catalogue's documents, `{barrio}_{pretext}`, have no [slot]: they hold
/// a place for every slot, and the phone expands them. A document with a
/// [slot], `{barrio}_{pretext}_{slot}`, is that one seat, and replaces its
/// expanded twin.
///
/// The fields are in `docs/ARCHITECTURE.md` § Data model.
/// {@endtemplate}
class const SeatFactsDocument({
  /// The document id: `{barrio}_{pretext}`, or `{barrio}_{pretext}_{slot}`
  /// for one seat.
  required final String seatId,

  /// The barrio of the seat's candidate ronda.
  required final String barrio,

  /// The ronda's pretext.
  required final String pretext,

  /// The ronda's slot, or `null` for a place that holds in every slot.
  required final String? slot,

  /// Blocks from each barrio's centroid to this seat's barrio, by barrio id.
  required final Map<String, double> blocksFrom,

  /// Whether reaching the place means climbing stairs; `false` until a host
  /// sets the place.
  required final bool hasStairs,

  /// Whether the slot ends after that week's sunset; `null` without a
  /// [slot].
  required final bool? endsAfterDark,

  /// Whether the place is hard to reach without a car; `false` until a host
  /// sets the place.
  required final bool needsCar,
}) {
  /// {@macro seat_facts_document}
  this;

  /// Reads the document [seatId] from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type,
  /// or when a [slot] comes without [endsAfterDark].
  factory fromJson(String seatId, Map<String, Object?> json) {
    if (json case {
      'barrio': final String barrio,
      'pretext': final String pretext,
      'blocksFrom': final Map<Object?, Object?> blocksFrom,
      'hasStairs': final bool hasStairs,
      'needsCar': final bool needsCar,
    }) {
      final (slot, endsAfterDark) = switch ((
        json['slot'],
        json['endsAfterDark'],
      )) {
        (null, _) => (null, null),
        (final String slot, final bool endsAfterDark) => (slot, endsAfterDark),
        _ => throw FormatException(
          'seat_facts/$seatId has a slot without endsAfterDark',
        ),
      };
      return SeatFactsDocument(
        seatId: seatId,
        barrio: barrio,
        pretext: pretext,
        slot: slot,
        blocksFrom: _blocksFrom(seatId, blocksFrom),
        hasStairs: hasStairs,
        endsAfterDark: endsAfterDark,
        needsCar: needsCar,
      );
    }
    throw FormatException('seat_facts/$seatId does not have the seat shape');
  }

  static Map<String, double> _blocksFrom(
    String seatId,
    Map<Object?, Object?> json,
  ) {
    final blocksFrom = <String, double>{};
    for (final MapEntry(:key, :value) in json.entries) {
      if ((key, value) case (final String barrio, final num blocks)) {
        blocksFrom[barrio] = blocks.toDouble();
      } else {
        throw FormatException(
          'seat_facts/$seatId has a walk that is not a number of blocks',
        );
      }
    }
    return blocksFrom;
  }
}
