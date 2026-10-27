import 'package:ronda_ui/ronda_ui.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

/// The "¿Entendimos bien?" [ReadBackCard].
@widgetbook.UseCase(name: 'default', type: ReadBackCard)
Widget readBackCard(BuildContext context) => SingleChildScrollView(
  padding: const EdgeInsets.all(AppSpacing.unit),
  child: ReadBackCard(
    identifier: 'demo',
    editLabel: 'Cambiar',
    fields: [
      for (final (id, label, value) in const [
        ('nombre', 'Te llamás', 'Graciela'),
        ('edad', 'Edad', 'sesenta y pico'),
        ('barrio', 'Barrio', 'Solymar Norte'),
        ('gusta', 'Te gusta', 'mate en la rambla, truco'),
        ('dias', 'Días que podés', 'martes y jueves de tarde'),
        ('traes', 'Podés llevar', 'bizcochos caseros'),
      ])
        ReadBackField(
          id: id,
          label: label,
          value: value,
          editSemanticsLabel: 'Cambiar $label',
          onEdit: () {},
        ),
    ],
  ),
);
