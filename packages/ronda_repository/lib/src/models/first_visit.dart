import 'package:equatable/equatable.dart';
import 'package:ronda_repository/src/models/hosts.dart';
import 'package:ronda_repository/src/models/this_week.dart';

/// {@template welcome}
/// One newcomer's first visit ("Así va a ser") and who waits for them: the
/// meeting, its place, the waiter and how to recognise them. Until a host
/// picks someone ([picked] is `false`), the waiter is whoever opens that
/// week: the member who took over opening it, else the anfitrión, read live
/// from the ronda.
/// {@endtemplate}
class const Welcome({
  /// The ronda.
  required final String rondaId,

  /// The newcomer's uid.
  required final String newcomerUid,

  /// Their first name.
  required final String newcomerName,

  /// The meeting's ISO week.
  required final String week,

  /// The meeting's date (local, at midnight).
  required final DateTime date,

  /// Who a host could pick: the members in for the meeting but the
  /// newcomer, in first-name order.
  final List<SetupMember> choices = const [],

  /// The meeting's hour (`16:00`), when it has one.
  final String? hour,

  /// The public place's name, once the admin set one.
  final String? placeName,

  /// How to find the place ("al lado de la parada").
  final String? placeLandmark,

  /// Who waits; `null` while the ronda has nobody to open.
  final Host? waiter,

  /// Whether a host picked [waiter], rather than whoever opens.
  final bool picked = false,

  /// How to recognise the waiter ("tiene el termo verde").
  final String? sign,

  /// The host who picked.
  final Host? setBy,

  /// Who last said "No puedo", by first name, while no host picked again.
  final String? declinedName,
}) extends Equatable {
  /// {@macro welcome}
  this;

  @override
  List<Object?> get props => [
    rondaId,
    newcomerUid,
    newcomerName,
    week,
    date,
    choices,
    hour,
    placeName,
    placeLandmark,
    waiter,
    picked,
    sign,
    setBy,
    declinedName,
  ];
}

/// {@template first_visit}
/// What a member's ronda asks of them about newcomers: their own "Así va a
/// ser" when they are new ([mine]), the newcomers a host chooses who waits
/// for ([toChoose], the anfitrión and the cola only), and the ones a host
/// picked them to wait for ([waitingFor]).
/// {@endtemplate}
class const FirstVisit({
  /// The ronda.
  required final String rondaId,

  /// This member's own welcome, when they are new.
  final Welcome? mine,

  /// The ronda's welcomes, for its anfitrión and cola.
  final List<Welcome> toChoose = const [],

  /// The welcomes a host picked this member to wait for.
  final List<Welcome> waitingFor = const [],
}) extends Equatable {
  /// {@macro first_visit}
  this;

  @override
  List<Object?> get props => [rondaId, mine, toChoose, waitingFor];
}
