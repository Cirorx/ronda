import 'package:ronda_ui/ronda_ui.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

/// "Quiénes van": a list of [PersonRow]s, the person using the app last.
@widgetbook.UseCase(name: 'quiénes van', type: PersonRow)
Widget quienesVan(BuildContext context) => ListView(
  padding: const EdgeInsets.all(AppSpacing.unit),
  children: const [
    PersonRow(
      initial: 'M',
      name: 'Mirta',
      detail: 'Llega primero · lleva el termo',
    ),
    PersonRow(
      initial: 'J',
      name: 'Jorge',
      detail: 'Se queda al final · enseña truco',
    ),
    PersonRow(
      initial: 'G',
      name: 'Vos',
      detail: 'Llevás el pan',
      isYou: true,
      showDivider: false,
    ),
  ],
);
