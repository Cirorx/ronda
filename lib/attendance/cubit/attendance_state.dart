part of 'attendance_cubit.dart';

/// Whether the roll can be shown.
enum AttendanceStatus {
  /// Reading.
  loading,

  /// [AttendanceState.roll] is the roll.
  ready,

  /// There is no roll for that meeting yet.
  none,

  /// The account isn't this ronda's host nor the admin.
  forbidden,

  /// It couldn't be read.
  failure,
}

final class const AttendanceState({
  final AttendanceStatus status = AttendanceStatus.loading,
  final AttendanceRoll? roll,

  /// Taps on their way to the server, by uid: shown before the roll has
  /// them.
  final Map<String, bool> pending = const {},

  /// Why the last tap didn't reach the server, until the next one.
  final HostsFailureReason? tapFailure,
}) extends Equatable {
  /// What shows for [uid]: their tap on its way, else the roll's mark, else
  /// `null` (not marked yet).
  bool? markOf(String uid) => pending[uid] ?? roll?.marks[uid];

  /// How many people on the roll show a mark.
  int get markedCount => [
    for (final person in roll?.people ?? const <SetupMember>[])
      if (markOf(person.uid) != null) person,
  ].length;

  /// The same roll with [pending] taps and the last [tapFailure].
  AttendanceState withTaps({
    required Map<String, bool> pending,
    required HostsFailureReason? tapFailure,
  }) => AttendanceState(
    status: status,
    roll: roll,
    pending: pending,
    tapFailure: tapFailure,
  );

  @override
  List<Object?> get props => [status, roll, pending, tapFailure];
}
