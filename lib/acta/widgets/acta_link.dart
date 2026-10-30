import 'package:go_router/go_router.dart';
import 'package:ronda/acta/view/acta_page.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Mi ronda's one line to ronda [rondaId]'s "Lo que hizo el programa".
class const ActaLink({
  /// The ronda whose acta it opens.
  required final String rondaId,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handle on the link.
  static const identifier = 'myRonda.acta';

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: TextButton(
          onPressed: () => context.push(ActaPage.location(rondaId)),
          child: Text(context.l10n.actaLink),
        ),
      ),
    );
  }
}
