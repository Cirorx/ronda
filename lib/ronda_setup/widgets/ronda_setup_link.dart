import 'package:go_router/go_router.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/ronda_setup/view/ronda_setup_page.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The admin screen's way to "Lugar, hora y anfitriones": an icon in its
/// app bar, named by its tooltip.
class const RondaSetupLink({super.key}) extends StatelessWidget {
  /// Maestro's handle on the link.
  static const identifier = 'admin_setup';

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: IconButton(
          onPressed: () => context.push(RondaSetupPage.path),
          tooltip: context.l10n.setupTitle,
          icon: const Icon(Icons.place_outlined),
        ),
      ),
    );
  }
}
