import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The Cerca tab. Until the list of open places exists, it says the list is
/// coming and points to Mi ronda, inside the page margins and scrolling at
/// large text.
class const CercaPage({super.key}) extends StatelessWidget {
  static const path = '/cerca';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cercaTabLabel)),
      body: ReadableColumn(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: context.appSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Text(
                  l10n.cercaPlaceholder,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
