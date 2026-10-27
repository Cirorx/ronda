import 'package:material_ui/material_ui.dart';
import 'package:ronda/l10n/l10n.dart';

/// The Mi ronda tab. A placeholder until this week's card exists.
class const MyRondaPage({super.key}) extends StatelessWidget {
  static const path = '/ronda';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myRondaTabLabel)),
      body: Center(
        child: Text(
          l10n.myRondaPlaceholder,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
