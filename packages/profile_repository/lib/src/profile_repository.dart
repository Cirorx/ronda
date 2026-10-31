import 'dart:convert';

import 'package:device_store/device_store.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda_api/ronda_api.dart';

/// {@template profile_repository}
/// A member's profile on `users/{uid}`, the conditions they accepted, and
/// the seat ids their needs let through.
///
/// It turns the wire documents from [RondaApi] into domain models and back.
/// It never handles needs: those stay on the phone in `needs_repository`,
/// and only the ids they allow reach `users/{uid}/private/eligible`.
///
/// Before anyone signs in, it holds the accepted conditions and the
/// onboarding answers on this phone, in [DeviceStore], so they survive
/// backing out of sign-in or the app being closed; once written to
/// `users/{uid}`, they are cleared. It also remembers whether this phone
/// has shown "¿Cómo funciona?", the cards before the welcome doors.
/// {@endtemplate}
class ProfileRepository {
  /// {@macro profile_repository}
  const new({required this._rondaApi, required this._deviceStore});

  final RondaApi _rondaApi;
  final DeviceStore _deviceStore;

  /// The device-store key that holds the accepted conditions until sign-in.
  static const heldTermsKey = 'held.terms';

  /// The device-store key that holds the onboarding answers until sign-in.
  static const heldAnswersKey = 'held.answers';

  /// The device-store key that says this phone has shown "¿Cómo funciona?".
  static const walkthroughSeenKey = 'walkthrough.seen';

  /// The profile of [uid] now and on every change; `null` until onboarding
  /// has saved one (the document may already hold the accepted terms).
  Stream<Profile?> watchProfile(String uid) =>
      _rondaApi.watchUser(uid).map((user) => user?.toProfile());

  /// Records on `users/{uid}` that [uid] accepted the conditions.
  ///
  /// Throws an [AcceptTermsFailure] when the write fails.
  Future<void> acceptTerms(String uid, TermsAcceptance terms) async {
    try {
      await _rondaApi.saveTerms(
        uid,
        TermsRecord(version: terms.version, acceptedAt: terms.acceptedAt),
      );
    } on Exception {
      throw const AcceptTermsFailure();
    }
  }

  /// Saves [profile] as the profile of [uid], keeping the accepted terms.
  ///
  /// Lists are stored in the enums' declaration order, so the same choices
  /// always produce the same document. Throws a [SaveProfileFailure] when
  /// the write fails.
  Future<void> createProfile(String uid, Profile profile) async {
    try {
      await _rondaApi.saveProfile(
        uid,
        firstName: profile.firstName,
        ageBand: profile.ageBand.id,
        barrio: profile.barrio.id,
        slots: _slotIds(profile),
        pretexts: _pretextIds(profile),
        brings: _bringIds(profile),
      );
    } on Exception {
      throw const SaveProfileFailure();
    }
  }

  /// Holds [terms] on this phone until someone signs in.
  ///
  /// Throws a [HoldOnPhoneFailure] when the phone can't keep them.
  Future<void> holdTerms(TermsAcceptance terms) => _hold(heldTermsKey, {
    'version': terms.version,
    'acceptedAt': terms.acceptedAt.toUtc().toIso8601String(),
  });

  /// The conditions held on this phone, or `null` when none are held or
  /// they can't be read.
  Future<TermsAcceptance?> heldTerms() async {
    if (await _held(heldTermsKey) case {
      'version': final String version,
      'acceptedAt': final String acceptedAt,
    }) {
      if (DateTime.tryParse(acceptedAt) case final at?) {
        return TermsAcceptance(version: version, acceptedAt: at.toLocal());
      }
    }
    return null;
  }

  /// Stops holding the conditions on this phone.
  ///
  /// Throws a [HoldOnPhoneFailure] when they can't be deleted.
  Future<void> clearHeldTerms() => _clear(heldTermsKey);

  /// Holds the onboarding [answers] on this phone until someone signs in.
  /// The needs are not part of them: `needs_repository` keeps those.
  ///
  /// Throws a [HoldOnPhoneFailure] when the phone can't keep them.
  Future<void> holdAnswers(Profile answers) => _hold(heldAnswersKey, {
    'firstName': answers.firstName,
    'ageBand': answers.ageBand.id,
    'barrio': answers.barrio.id,
    'pretexts': _pretextIds(answers),
    'slots': _slotIds(answers),
    'brings': _bringIds(answers),
  });

  /// The onboarding answers held on this phone, or `null` when none are
  /// held or they can't be read.
  Future<Profile?> heldAnswers() async {
    if (await _held(heldAnswersKey) case {
      'firstName': final String firstName,
      'ageBand': final String ageBandId,
      'barrio': final String barrioId,
      'pretexts': final List<Object?> pretexts,
      'slots': final List<Object?> slots,
      'brings': final List<Object?> brings,
    }) {
      if ((AgeBand.fromId(ageBandId), Barrio.fromId(barrioId))
          case (final ageBand?, final barrio?) when firstName.isNotEmpty) {
        return Profile(
          firstName: firstName,
          ageBand: ageBand,
          barrio: barrio,
          pretexts: {
            for (final id in pretexts.whereType<String>()) ?Pretext.fromId(id),
          },
          slots: {for (final id in slots.whereType<String>()) ?Slot.fromId(id)},
          brings: {
            for (final id in brings.whereType<String>()) ?Bring.fromId(id),
          },
        );
      }
    }
    return null;
  }

  /// Stops holding the onboarding answers on this phone.
  ///
  /// Throws a [HoldOnPhoneFailure] when they can't be deleted.
  Future<void> clearHeldAnswers() => _clear(heldAnswersKey);

  /// Whether this phone has shown "¿Cómo funciona?"; `false` when it
  /// hasn't or that can't be read.
  Future<bool> walkthroughSeen() async =>
      await _held(walkthroughSeenKey) == true;

  /// Remembers on this phone that "¿Cómo funciona?" was shown.
  ///
  /// Throws a [HoldOnPhoneFailure] when the phone can't keep it.
  Future<void> markWalkthroughSeen() => _hold(walkthroughSeenKey, true);

  Future<void> _hold(String key, Object json) async {
    try {
      await _deviceStore.write(key, jsonEncode(json));
    } on Exception {
      throw const HoldOnPhoneFailure();
    }
  }

  Future<Object?> _held(String key) async {
    try {
      return switch (await _deviceStore.read(key)) {
        final stored? => jsonDecode(stored),
        null => null,
      };
    } on Exception {
      return null;
    }
  }

  Future<void> _clear(String key) async {
    try {
      await _deviceStore.delete(key);
    } on Exception {
      throw const HoldOnPhoneFailure();
    }
  }

  /// The ids of the profile's lists in the enums' declaration order, so the
  /// same choices always produce the same document.
  static List<String> _slotIds(Profile profile) => [
    for (final day in SlotDay.values)
      for (final band in SlotBand.values)
        if (profile.slots.contains(Slot(day, band))) Slot(day, band).id,
  ];

  static List<String> _pretextIds(Profile profile) => [
    for (final pretext in Pretext.values)
      if (profile.pretexts.contains(pretext)) pretext.id,
  ];

  static List<String> _bringIds(Profile profile) => [
    for (final bring in Bring.values)
      if (profile.brings.contains(bring)) bring.id,
  ];

  /// Every seat the server publishes, for the phone's needs filter.
  ///
  /// Throws a [ReadPublishedSeatsFailure] when the read fails.
  Future<List<PublishedSeat>> publishedSeats() async {
    try {
      final seats = await _rondaApi.readSeatFacts();
      return [
        for (final seat in seats)
          PublishedSeat(
            seatId: seat.seatId,
            blocksFrom: seat.blocksFrom,
            hasStairs: seat.hasStairs,
            endsAfterDark: seat.endsAfterDark,
            needsCar: seat.needsCar,
          ),
      ];
    } on Exception {
      throw const ReadPublishedSeatsFailure();
    }
  }

  /// Replaces the eligible seat ids of [uid] with [seatIds]: the only trace
  /// of their needs that leaves the phone.
  ///
  /// Throws a [SaveEligibleSeatIdsFailure] when the write fails.
  Future<void> saveEligibleSeatIds({
    required String uid,
    required List<String> seatIds,
  }) async {
    try {
      await _rondaApi.writeEligibleSeatIds(uid: uid, seatIds: seatIds);
    } on Exception {
      throw const SaveEligibleSeatIdsFailure();
    }
  }
}

extension on UserDocument {
  /// The profile this document holds, or `null` while onboarding hasn't
  /// saved its required fields.
  Profile? toProfile() {
    final name = firstName;
    final band = AgeBand.fromId(ageBand);
    final place = Barrio.fromId(barrio);
    if (name == null || name.isEmpty || band == null || place == null) {
      return null;
    }
    return Profile(
      firstName: name,
      ageBand: band,
      barrio: place,
      pretexts: {for (final id in pretexts) ?Pretext.fromId(id)},
      slots: {for (final id in slots) ?Slot.fromId(id)},
      brings: {for (final id in brings) ?Bring.fromId(id)},
    );
  }
}
