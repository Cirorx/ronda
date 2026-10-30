import 'package:material_ui/material_ui.dart';
import 'package:ronda/l10n/l10n.dart';

/// The Cerca tab. Until the list of open places exists, it says the list is
/// coming and points to Mi ronda.
class const CercaPage({super.key}) extends StatelessWidget {
  static const path = '/cerca';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cercaTabLabel)),
      body: Center(
        child: Text(
          l10n.cercaPlaceholder,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
