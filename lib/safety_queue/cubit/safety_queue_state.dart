part of 'safety_queue_cubit.dart';

/// Whether the queue can show the reports.
enum SafetyQueueStatus {
  /// Reading.
  loading,

  /// [SafetyQueueState.queue] is what the server holds.
  ready,

  /// The account isn't the admin.
  forbidden,

  /// The queue couldn't be read.
  failure,
}

/// Which reports the queue lists.
enum SafetyQueueTab {
  /// "Abiertos": every report not archived, withdrawn ones included.
  open,

  /// "Archivados".
  archived,
}

final class const SafetyQueueState({
  final SafetyQueueStatus status = SafetyQueueStatus.loading,
  final SafetyQueue queue = const SafetyQueue(),
  final SafetyQueueTab tab = SafetyQueueTab.open,

  /// The reports that were unread when this visit first saw them: they
  /// show "Nuevo" while the screen is open, though they are marked read.
  final Set<String> fresh = const {},

  /// The report, pair or person being acted on.
  final String? busy,

  /// Whether the last action failed.
  final bool actionFailed = false,
}) extends Equatable {
  /// The fewest different reporters that put someone on top of the queue.
  static const topReporters = 2;

  /// How many different people reported [aboutUid], over every report.
  int reportersOf(String aboutUid) => aboutUid.isEmpty
      ? 0
      : {
          for (final report in queue.reports)
            if (report.aboutUid == aboutUid) report.reporterUid,
        }.length;

  /// The reports [tab] lists: anyone reported by two or more different
  /// people first, then the newest.
  List<Report> get shown {
    final listed = [
      for (final report in queue.reports)
        if (report.archived == (tab == SafetyQueueTab.archived)) report,
    ];
    final top = [
      for (final report in listed)
        if (reportersOf(report.aboutUid) >= topReporters) report,
    ];
    return [
      ...top,
      for (final report in listed)
        if (!top.contains(report)) report,
    ];
  }

  /// How many reports are open.
  int get openCount => queue.reports.where((r) => !r.archived).length;

  /// The pair [report] separated, if its two are kept apart.
  SeparatedPair? separationOf(Report report) => report.aboutOutsider
      ? null
      : queue.separated
            .where((pair) => pair.joins(report.reporterUid, report.aboutUid))
            .firstOrNull;

  /// Whether [uid] is out of Ronda.
  bool isRemoved(String uid) => queue.removed.any((p) => p.uid == uid);

  SafetyQueueState copyWith({
    SafetyQueueStatus? status,
    SafetyQueue? queue,
    SafetyQueueTab? tab,
    Set<String>? fresh,
    String? Function()? busy,
    bool? actionFailed,
  }) => SafetyQueueState(
    status: status ?? this.status,
    queue: queue ?? this.queue,
    tab: tab ?? this.tab,
    fresh: fresh ?? this.fresh,
    busy: busy == null ? this.busy : busy(),
    actionFailed: actionFailed ?? this.actionFailed,
  );

  @override
  List<Object?> get props => [status, queue, tab, fresh, busy, actionFailed];
}
