/// {@template pilot_numbers_document}
/// What `pilot_numbers` answers (`functions/pilot_numbers.py`): the pilot's
/// counts, each as "x of y", with the invented sign-ups left out where they
/// don't count. Counts only: no name, no uid.
/// {@endtemplate}
class const PilotNumbersDocument({
  /// Sign-ups who saved a profile.
  required final int profiles,

  /// Sign-ups: `users/{uid}` documents, the terms accepted.
  required final int signUps,

  /// Of [profiles], how many sit in a ronda that still meets.
  required final int seated,

  /// Each ronda with a member who counts.
  required final List<PilotRondaDocument> rondas,

  /// Came back, over every ronda; `null` until a ronda marked two
  /// meetings.
  final CountOfDocument? cameBack,
}) {
  /// {@macro pilot_numbers_document}
  this;

  /// Reads the callable's answer.
  ///
  /// Throws a [FormatException] for any other shape.
  factory fromJson(Object? json) {
    if (json case {
      'signUps': {'profiles': final int profiles, 'of': final int signUps},
      'seated': {'members': final int seated},
      'rondas': final List<Object?> rondas,
      'cameBack': final Object? cameBack,
    }) {
      return PilotNumbersDocument(
        profiles: profiles,
        signUps: signUps,
        seated: seated,
        rondas: [
          for (final ronda in rondas) PilotRondaDocument.fromJson(ronda),
        ],
        cameBack: CountOfDocument.maybe(cameBack),
      );
    }
    throw _shape;
  }
}

/// {@template pilot_ronda_document}
/// One ronda's numbers.
/// {@endtemplate}
class const PilotRondaDocument({
  /// The ronda's id.
  required final String rondaId,

  /// Its es-419 line.
  required final String line,

  /// `forming`, `active`, `paused` or `ended`.
  required final String status,

  /// Members sitting in it (active and paused).
  required final int members,

  /// The most its pretext allows.
  required final int cap,

  /// Each week it has, by week id.
  required final List<PilotWeekDocument> weeks,

  /// Of who came to its first marked meeting, how many came to the next.
  final CountOfDocument? cameBack,

  /// Its ¿seguimos? counts, once asked.
  final PilotSeguimosDocument? seguimos,
}) {
  /// {@macro pilot_ronda_document}
  this;

  /// Reads one entry of `rondas`.
  factory fromJson(Object? json) {
    if (json case {
      'rondaId': final String rondaId,
      'line': final String line,
      'status': final String status,
      'members': final int members,
      'cap': final int cap,
      'weeks': final List<Object?> weeks,
      'cameBack': final Object? cameBack,
      'seguimos': final Object? seguimos,
    }) {
      return PilotRondaDocument(
        rondaId: rondaId,
        line: line,
        status: status,
        members: members,
        cap: cap,
        weeks: [for (final week in weeks) PilotWeekDocument.fromJson(week)],
        cameBack: CountOfDocument.maybe(cameBack),
        seguimos: switch (seguimos) {
          null => null,
          {
            'status': final String status,
            'asked': final int asked,
            'yes': final int yes,
            'no': final int no,
            'unanswered': final int unanswered,
          } =>
            PilotSeguimosDocument(
              status: status,
              asked: asked,
              yes: yes,
              no: no,
              unanswered: unanswered,
            ),
          _ => throw _shape,
        },
      );
    }
    throw _shape;
  }
}

/// {@template pilot_week_document}
/// One week of one ronda: the RSVP and who came.
/// {@endtemplate}
class const PilotWeekDocument({
  /// The ISO week (`2026-W45`).
  required final String week,

  /// The members that week.
  required final int members,

  /// Said voy.
  required final int yes,

  /// Can't (said no, or paused over the meeting).
  required final int no,

  /// Didn't answer.
  required final int unanswered,

  /// The meeting's date, `YYYY-MM-DD`, when stored.
  final String? date,

  /// How many came; `null` while the host hasn't marked.
  final int? came,

  /// How many the host marked; `null` while unmarked.
  final int? marked,
}) {
  /// {@macro pilot_week_document}
  this;

  /// Reads one entry of `weeks`.
  factory fromJson(Object? json) {
    if (json case {
      'week': final String week,
      'date': final String? date,
      'members': final int members,
      'yes': final int yes,
      'no': final int no,
      'unanswered': final int unanswered,
      'came': final int? came,
      'marked': final int? marked,
    }) {
      return PilotWeekDocument(
        week: week,
        date: date,
        members: members,
        yes: yes,
        no: no,
        unanswered: unanswered,
        came: came,
        marked: marked,
      );
    }
    throw _shape;
  }
}

/// {@template count_of_document}
/// "x of y".
/// {@endtemplate}
class const CountOfDocument(final int count, final int of) {
  /// {@macro count_of_document}
  this;

  /// `{came, of}`, or `null`.
  static CountOfDocument? maybe(Object? json) => switch (json) {
    null => null,
    {'came': final int came, 'of': final int of} => CountOfDocument(came, of),
    _ => throw _shape,
  };
}

/// {@template pilot_seguimos_document}
/// A ronda's ¿seguimos? counts, from `seguimos_counts/{rondaId}`.
/// {@endtemplate}
class const PilotSeguimosDocument({
  /// `open`, `season` or `didntFill`.
  required final String status,

  /// Members asked.
  required final int asked,

  /// Said sí.
  required final int yes,

  /// Said no.
  required final int no,

  /// Haven't answered.
  required final int unanswered,
}) {
  /// {@macro pilot_seguimos_document}
  this;
}

const _shape = FormatException('not the shape pilot_numbers.py answers');
