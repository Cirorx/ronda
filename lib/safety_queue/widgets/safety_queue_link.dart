import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ronda/app/cubit/unread_reports_cubit.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/safety_queue/view/safety_queue_page.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The admin screen's way to the reports: an icon in its app bar, named by
/// its tooltip, with the unread count on it.
class const SafetyQueueLink({super.key}) extends StatelessWidget {
  /// Maestro's handle on the link.
  static const identifier = 'admin_reports';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unread = context.watch<UnreadReportsCubit>().state;
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        value: unread > 0 ? l10n.safetyUnread(unread) : null,
        child: IconButton(
          onPressed: () => context.push(SafetyQueuePage.path),
          tooltip: l10n.safetyQueueLink,
          icon: UnreadBadge(
            count: unread,
            child: const Icon(Icons.report_outlined),
          ),
        ),
      ),
    );
  }
}

/// [child] with [count] on it while there is any; the count itself is left
/// out of the semantics, which say it in words where it is shown.
class const UnreadBadge({
  required final int count,
  required final Widget child,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Badge.count(count: count, isLabelVisible: count > 0, child: child),
  );
}
