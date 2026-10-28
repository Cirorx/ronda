import 'package:material_ui/material_ui.dart';
import 'package:ronda/l10n/l10n.dart';

/// The Mi ronda tab. A placeholder until this week's card exists.
class const MyRondaPage({super.key}) extends StatelessWidget {
  static const path = '/ronda';

  /// Maestro's handle on the tab's content, where a flow checks that it
  /// reached Mi ronda. It wraps the whole body, so it outlives whatever the
  /// body shows.
  static const identifier = 'myRonda';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myRondaTabLabel)),
      body: Semantics(
        container: true,
        identifier: identifier,
        child: Center(
          child: Text(
            l10n.myRondaPlaceholder,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
