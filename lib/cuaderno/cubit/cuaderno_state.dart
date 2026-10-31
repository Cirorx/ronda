part of 'cuaderno_cubit.dart';

/// Whether the cuaderno could be read from the phone.
enum CuadernoStatus { loading, ready, failure }

/// What went wrong last, shown until the next step.
enum CuadernoFailure {
  /// A line couldn't be written, changed or deleted on the phone.
  write,

  /// The postcard couldn't be drawn.
  postcard,

  /// The week's lines held nothing a postcard can show.
  nothingToDraw,

  /// The share sheet didn't open.
  share,
}

final class const CuadernoState({
  final CuadernoStatus status = CuadernoStatus.loading,
  final Cuaderno cuaderno = Cuaderno.empty,

  /// Today, a date at midnight, as of the last read.
  final DateTime? today,

  /// The ronda's next meeting, a date at midnight; `null` with no ronda.
  final DateTime? meetingDate,

  /// Today's line is being written.
  final bool writing = false,

  /// Today's line was just written ("Anotado.").
  final bool wrote = false,

  /// The postcard is being drawn.
  final bool makingPostcard = false,

  /// The postcard drawn, held in memory only.
  final Postcard? postcard,

  /// The last failure, if the last step failed.
  final CuadernoFailure? failure,
}) extends Equatable {
  CuadernoState copyWith({
    CuadernoStatus? status,
    Cuaderno? cuaderno,
    DateTime? today,
    DateTime? Function()? meetingDate,
    bool? writing,
    bool? wrote,
    bool? makingPostcard,
    Postcard? Function()? postcard,
    CuadernoFailure? Function()? failure,
  }) => CuadernoState(
    status: status ?? this.status,
    cuaderno: cuaderno ?? this.cuaderno,
    today: today ?? this.today,
    meetingDate: meetingDate == null ? this.meetingDate : meetingDate(),
    writing: writing ?? this.writing,
    wrote: wrote ?? this.wrote,
    makingPostcard: makingPostcard ?? this.makingPostcard,
    postcard: postcard == null ? this.postcard : postcard(),
    failure: failure == null ? this.failure : failure(),
  );

  /// Today's line, if it was written.
  CuadernoEntry? get todaysLine => switch (today) {
    final today? => cuaderno.on(today),
    null => null,
  };

  /// The week's lines: the last seven days, today included, oldest first.
  List<CuadernoEntry> get weekLines => switch (today) {
    final today? => cuaderno.between(
      DateTime(today.year, today.month, today.day - 6),
      today,
    ),
    null => const [],
  };

  /// Whether the postcard can be drawn now: on the day before the ronda's
  /// meeting or on the day itself, with at least one line this week.
  bool get postcardOffered {
    final today = this.today;
    final meeting = meetingDate;
    if (today == null || meeting == null || weekLines.isEmpty) return false;
    final eve = DateTime(meeting.year, meeting.month, meeting.day - 1);
    return today == eve || today == meeting;
  }

  @override
  List<Object?> get props => [
    status,
    cuaderno,
    today,
    meetingDate,
    writing,
    wrote,
    makingPostcard,
    postcard,
    failure,
  ];
}
