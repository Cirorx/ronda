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

  /// The device-store key that holds the language picked for Ronda.
  static const languageKey = 'app.language';

  /// The device-store key, before `.{uid}`, that holds the seat catalogue
  /// version the person's eligible seats were last worked out against.
  static const seatCatalogKey = 'seats.catalog';

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
  Future<void> createProfile(String uid, Profile profile) =>
      _saveProfile(uid, profile, isNew: true);

  /// Replaces the profile of [uid] with [profile], from "Mis datos": casa,
  /// trabajo and every answer, keeping when it was first saved. A profile
  /// saved before trabajo existed gains its fields here.
  ///
  /// Throws a [SaveProfileFailure] when the write fails.
  Future<void> updateProfile(String uid, Profile profile) =>
      _saveProfile(uid, profile, isNew: false);

  Future<void> _saveProfile(
    String uid,
    Profile profile, {
    required bool isNew,
  }) async {
    final work = profile.anchors.skip(1).firstOrNull;
    try {
      await _rondaApi.saveProfile(
        uid,
        firstName: profile.firstName,
        ageBand: profile.ageBand.id,
        barrio: profile.barrio.id,
        barrioNeighbours: profile.barrioNeighbours,
        workBarrio: work?.barrio.id,
        workBarrioNeighbours: work?.neighbours ?? false,
        slots: _slotIds(profile),
        pretexts: _pretextIds(profile),
        brings: _bringIds(profile),
        isNew: isNew,
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
    'barrioNeighbours': answers.barrioNeighbours,
    if (answers.anchors.skip(1).firstOrNull case final work?) ...{
      'workBarrio': work.barrio.id,
      'workBarrioNeighbours': work.neighbours,
    },
    'pretexts': _pretextIds(answers),
    'slots': _slotIds(answers),
    'brings': _bringIds(answers),
  });

  /// The onboarding answers held on this phone, or `null` when none are
  /// held or they can't be read.
  Future<Profile?> heldAnswers() async {
    final held = await _held(heldAnswersKey);
    if (held case {
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
          barrioNeighbours: held['barrioNeighbours'] == true,
          work: _work(held['workBarrio'], held['workBarrioNeighbours']),
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

  /// The language picked for Ronda on this phone; `null` when none was
  /// picked (the app follows the phone) or it can't be read.
  Future<AppLanguage?> language() async =>
      AppLanguage.fromId(await _held(languageKey));

  /// Remembers [language] for Ronda on this phone, or, with `null`, goes
  /// back to following the phone's language.
  ///
  /// Throws a [HoldOnPhoneFailure] when the phone can't keep it.
  Future<void> holdLanguage(AppLanguage? language) => switch (language) {
    final language? => _hold(languageKey, language.id),
    null => _clear(languageKey),
  };

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

  /// Trabajo from its stored id and switch, or `null` for none or an
  /// unknown barrio.
  static Anchor? _work(Object? barrioId, Object? neighbours) =>
      switch (Barrio.fromId(barrioId is String ? barrioId : null)) {
        final barrio? => Anchor(barrio: barrio, neighbours: neighbours == true),
        null => null,
      };

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
  /// Each place of the catalogue becomes a seat in every slot,
  /// `{barrio}_{pretext}_{slot}`, ending after dark in the evening; a seat a
  /// host set for one slot replaces its twin.
  ///
  /// Throws a [ReadPublishedSeatsFailure] when the read fails.
  Future<List<PublishedSeat>> publishedSeats() async {
    final List<SeatFactsDocument> documents;
    try {
      documents = await _rondaApi.readSeatFacts();
    } on Exception {
      throw const ReadPublishedSeatsFailure();
    }
    final seats = <String, PublishedSeat>{};
    for (final place in documents.where((document) => document.slot == null)) {
      for (final day in SlotDay.values) {
        for (final band in SlotBand.values) {
          final seatId =
              '${place.barrio}_${place.pretext}_'
              '${Slot(day, band).id}';
          seats[seatId] = PublishedSeat(
            seatId: seatId,
            blocksFrom: place.blocksFrom,
            hasStairs: place.hasStairs,
            endsAfterDark: band == SlotBand.evening,
            needsCar: place.needsCar,
          );
        }
      }
    }
    for (final document in documents) {
      if (document case SeatFactsDocument(
        slot: _?,
        endsAfterDark: final endsAfterDark?,
      )) {
        seats[document.seatId] = PublishedSeat(
          seatId: document.seatId,
          blocksFrom: document.blocksFrom,
          hasStairs: document.hasStairs,
          endsAfterDark: endsAfterDark,
          needsCar: document.needsCar,
        );
      }
    }
    return seats.values.toList();
  }

  /// The version of the seat catalogue the server published, or `null`
  /// before it published one.
  ///
  /// Throws a [ReadPublishedSeatsFailure] when the read fails.
  Future<String?> publishedSeatCatalogVersion() async {
    try {
      return await _rondaApi.readSeatCatalogVersion();
    } on Exception {
      throw const ReadPublishedSeatsFailure();
    }
  }

  /// The catalogue version [uid]'s eligible seats were last worked out
  /// against on this phone, or `null` when they weren't here or it can't be
  /// read.
  Future<String?> seatCatalogWorkedOut(String uid) async =>
      switch (await _held('$seatCatalogKey.$uid')) {
        final String version => version,
        _ => null,
      };

  /// Remembers on this phone that [uid]'s eligible seats were worked out
  /// against the catalogue [version].
  ///
  /// Throws a [HoldOnPhoneFailure] when the phone can't keep it.
  Future<void> holdSeatCatalogWorkedOut(String uid, String version) =>
      _hold('$seatCatalogKey.$uid', version);

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
      barrioNeighbours: barrioNeighbours,
      work: ProfileRepository._work(workBarrio, workBarrioNeighbours),
    );
  }
}
