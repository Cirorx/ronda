import 'package:profile_repository/profile_repository.dart';
import 'package:ronda_api/ronda_api.dart';

/// {@template profile_repository}
/// A member's profile on `users/{uid}`, and the conditions they accepted.
///
/// It turns the wire document from [RondaApi] into a [Profile] and back. It
/// never handles needs: those stay on the phone in `needs_repository`.
/// {@endtemplate}
class ProfileRepository {
  /// {@macro profile_repository}
  const new({required this._rondaApi});

  final RondaApi _rondaApi;

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
        slots: [
          for (final day in SlotDay.values)
            for (final band in SlotBand.values)
              if (profile.slots.contains(Slot(day, band))) Slot(day, band).id,
        ],
        pretexts: [
          for (final pretext in Pretext.values)
            if (profile.pretexts.contains(pretext)) pretext.id,
        ],
        brings: [
          for (final bring in Bring.values)
            if (profile.brings.contains(bring)) bring.id,
        ],
      );
    } on Exception {
      throw const SaveProfileFailure();
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
