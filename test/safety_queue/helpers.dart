import 'package:safety_repository/safety_repository.dart';

/// Invented reports for the queue's tests: Ana and Cora both told about
/// Beto, Dani about someone from outside, Eva's was archived.
abstract final class SafetyFixtures {
  static final at = DateTime.utc(2026, 11, 2, 15);

  static Report report({
    String id = 'rep1',
    String reporterUid = 'ana',
    String reporterName = 'Ana',
    String aboutUid = 'beto',
    String aboutName = 'Beto',
    DateTime? createdAt,
    bool archived = false,
    bool withdrawn = false,
    bool unread = false,
    List<ReportAddition> additions = const [],
  }) => Report(
    id: id,
    reporterUid: reporterUid,
    reporterName: reporterName,
    aboutUid: aboutUid,
    aboutName: aboutName,
    createdAt: createdAt ?? at,
    rondaLine: 'Sábado a la tarde · mate en la rambla',
    tags: const [ReportTag.bothered],
    text: 'Me insistió',
    additions: additions,
    archived: archived,
    withdrawn: withdrawn,
    unread: unread,
  );

  static final Report beto = report(unread: true);
  static final Report cora = report(
    id: 'rep2',
    reporterUid: 'cora',
    reporterName: 'Cora',
    createdAt: DateTime.utc(2026, 10, 30),
  );
  static final Report outside = report(
    id: 'rep3',
    reporterUid: 'dani',
    reporterName: 'Dani',
    aboutUid: '',
    aboutName: '',
    createdAt: DateTime.utc(2026, 11, 3),
  );
  static final Report archived = report(
    id: 'rep4',
    reporterUid: 'eva',
    reporterName: 'Eva',
    aboutUid: 'fede',
    aboutName: 'Fede',
    archived: true,
  );

  static final queue = SafetyQueue(reports: [outside, beto, cora, archived]);
}
