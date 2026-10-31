import 'package:equatable/equatable.dart';

/// {@template calendar_event}
/// One event for a calendar: a [title], when it [start]s and [end]s in the
/// phone's own time zone, and where, when there is a place to name.
/// {@endtemplate}
class const CalendarEvent({
  required final String title,
  required final DateTime start,
  required final DateTime end,
  final String? location,
}) extends Equatable {
  /// {@macro calendar_event}
  this;

  @override
  List<Object?> get props => [title, start, end, location];
}
