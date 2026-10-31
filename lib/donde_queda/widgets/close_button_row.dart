import 'package:go_router/go_router.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/my_ronda.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// [Volver a Mi ronda]: back where the screen was opened from, or to Mi
/// ronda when it was opened from a link.
class const CloseButtonRow({super.key}) extends StatelessWidget {
  /// Maestro's handle.
  static const identifier = 'dondeQueda.close';

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: FilledButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(MyRondaPage.path),
          child: Text(context.l10n.dondeQuedaBackToRonda),
        ),
      ),
    );
  }
}
