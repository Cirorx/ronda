import 'package:go_router/go_router.dart';
import 'package:ronda/error_log/view/error_log_page.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The admin screen's way to the app's errors: an icon in its app bar,
/// named by its tooltip.
class const ErrorLogLink({super.key}) extends StatelessWidget {
  /// Maestro's handle on the link.
  static const identifier = 'admin_errors';

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: IconButton(
          onPressed: () => context.push(ErrorLogPage.path),
          tooltip: context.l10n.errorLogLink,
          icon: const Icon(Icons.bug_report_outlined),
        ),
      ),
    );
  }
}
