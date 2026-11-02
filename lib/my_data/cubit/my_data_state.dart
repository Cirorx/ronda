part of 'my_data_cubit.dart';

/// Where "Mis datos" stands.
enum MyDataStatus {
  /// Reading the profile.
  loading,

  /// The profile could not be read.
  loadFailure,

  /// The answers are open to change.
  editing,

  /// The eligible ids and the profile are being written.
  saving,

  /// Everything was written.
  saved,

  /// A write failed; the answers stay as they are.
  saveFailure;

  /// Whether a save is running.
  bool get isUnderway => this == saving;
}

/// {@template my_data_state}
/// The member's answers as "Mis datos" shows them, the profile they were read
/// from, and whether the member already sits in a ronda.
/// {@endtemplate}
class const MyDataState({
  final MyDataStatus status = MyDataStatus.loading,

  /// The profile as saved, to tell what changed.
  final Profile? saved,
  final FirstName firstName = const FirstName.pure(),
  final AgeBand? ageBand,

  /// Casa, required.
  final Anchor? home,

  /// Trabajo, optional.
  final Anchor? work,
  final Set<Pretext> pretexts = const {},
  final Set<Slot> slots = const {},
  final Set<Bring> brings = const {},

  /// Whether the member sits in a ronda that still meets.
  final bool seated = false,
}) extends Equatable {
  /// {@macro my_data_state}
  this;

  /// The state for [profile], open to change.
  factory fromProfile(Profile profile, {required bool seated}) => MyDataState(
    status: MyDataStatus.editing,
    saved: profile,
    firstName: FirstName.dirty(profile.firstName),
    ageBand: profile.ageBand,
    home: profile.home,
    work: profile.anchors.skip(1).firstOrNull,
    pretexts: profile.pretexts,
    slots: profile.slots,
    brings: profile.brings,
    seated: seated,
  );

  /// Whether every answer a profile needs is in.
  bool get isComplete =>
      firstName.isValid &&
      ageBand != null &&
      home != null &&
      pretexts.isNotEmpty &&
      slots.isNotEmpty &&
      brings.isNotEmpty;

  /// The profile these answers make, or `null` while one is missing.
  Profile? get profile => switch ((ageBand, home)) {
    (final ageBand?, final home?) when isComplete => Profile(
      firstName: firstName.name,
      ageBand: ageBand,
      barrio: home.barrio,
      barrioNeighbours: home.neighbours,
      work: work,
      pretexts: pretexts,
      slots: slots,
      brings: brings,
    ),
    _ => null,
  };

  /// Whether a barrio or the times differ from the saved profile: what a
  /// seated member is told counts only from the next grouping.
  bool get changesMatching => switch ((saved, profile)) {
    (final saved?, final edited?) =>
      !_sameList(saved.anchors, edited.anchors) ||
          !_sameSet(saved.slots, edited.slots),
    _ => false,
  };

  static bool _sameList<T>(List<T> a, List<T> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);

  static bool _sameSet<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);

  MyDataState copyWith({
    MyDataStatus? status,
    Profile? saved,
    FirstName? firstName,
    AgeBand? ageBand,
    Anchor? home,
    Anchor? Function()? work,
    Set<Pretext>? pretexts,
    Set<Slot>? slots,
    Set<Bring>? brings,
    bool? seated,
  }) => MyDataState(
    status: status ?? this.status,
    saved: saved ?? this.saved,
    firstName: firstName ?? this.firstName,
    ageBand: ageBand ?? this.ageBand,
    home: home ?? this.home,
    work: work == null ? this.work : work(),
    pretexts: pretexts ?? this.pretexts,
    slots: slots ?? this.slots,
    brings: brings ?? this.brings,
    seated: seated ?? this.seated,
  );

  @override
  List<Object?> get props => [
    status,
    saved,
    firstName,
    ageBand,
    home,
    work,
    pretexts,
    slots,
    brings,
    seated,
  ];
}
