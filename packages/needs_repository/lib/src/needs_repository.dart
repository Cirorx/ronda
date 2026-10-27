import 'dart:convert';

import 'package:device_store/device_store.dart';
import 'package:needs_repository/src/models/models.dart';

/// {@template needs_repository}
/// A member's needs, kept on the phone only, and the seat filter they drive.
///
/// It has no network path: needs never leave the device.
/// {@endtemplate}
class NeedsRepository {
  /// {@macro needs_repository}
  const new({required this._deviceStore});

  final DeviceStore _deviceStore;

  /// The device-store key that holds the needs, as one JSON value.
  static const storageKey = 'needs';

  /// The needs saved on this phone, or [Needs.none] when nothing is saved
  /// or the saved value can't be read.
  Future<Needs> read() async {
    final stored = await _deviceStore.read(storageKey);
    if (stored == null) return Needs.none;
    try {
      return _decode(jsonDecode(stored));
    } on FormatException {
      return Needs.none;
    }
  }

  /// Saves [needs] on this phone, replacing what was saved before.
  Future<void> save(Needs needs) => _deviceStore.write(
    storageKey,
    jsonEncode({
      'needs': [
        for (final need in Need.values)
          if (needs.values.contains(need)) need.name,
      ],
    }),
  );

  /// Deletes the needs saved on this phone.
  Future<void> clear() => _deviceStore.delete(storageKey);

  /// The ids of the [seats] that [needs] allow, in the order given.
  List<String> eligibleSeatIds(Needs needs, List<SeatFacts> seats) => [
    for (final seat in seats)
      if (_fits(needs.values, seat)) seat.seatId,
  ];

  static Needs _decode(Object? json) {
    if (json case {'needs': final List<Object?> names}) {
      final byName = Need.values.asNameMap();
      return Needs({
        for (final name in names.whereType<String>()) ?byName[name],
      });
    }
    return Needs.none;
  }

  static bool _fits(Set<Need> needs, SeatFacts seat) =>
      !needs.any((need) => _excludes(need, seat));

  static bool _excludes(Need need, SeatFacts seat) => switch (need) {
    Need.walkALot => seat.walkDistance == WalkDistance.far,
    Need.climbStairs => seat.hasStairs,
    Need.returnAfterDark => seat.endsAfterDark,
    Need.noCar => seat.needsCar,
  };
}
