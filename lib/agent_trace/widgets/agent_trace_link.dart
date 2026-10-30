import 'package:go_router/go_router.dart';
import 'package:ronda/agent_trace/view/agent_trace_page.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The admin screen's way to "Lo que mandó el programa": an icon in its app
/// bar, named by its tooltip.
class const AgentTraceLink({super.key}) extends StatelessWidget {
  /// Maestro's handle on the link.
  static const identifier = 'admin_trace';

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: IconButton(
          onPressed: () => context.push(AgentTracePage.path),
          tooltip: context.l10n.traceTitle,
          icon: const Icon(Icons.timeline),
        ),
      ),
    );
  }
}
