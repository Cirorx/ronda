import 'package:ronda_ui/ronda_ui.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _days = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _bands = ['Mañana', 'Tarde', 'Noche'];

/// The "¿Cuándo podés?" [SlotGrid]. Raise the text scale to see the chips.
@widgetbook.UseCase(name: 'default', type: SlotGrid)
Widget slotGrid(BuildContext context) => const _SlotGridDemo();

class _SlotGridDemo extends StatefulWidget {
  const new();

  @override
  State<_SlotGridDemo> createState() => _SlotGridDemoState();
}

class _SlotGridDemoState extends State<_SlotGridDemo> {
  var _selected = <SlotGridCell>{(day: 1, band: 1), (day: 3, band: 1)};

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.unit),
    child: SlotGrid(
      identifier: 'demo',
      dayLabels: _days,
      bandLabels: _bands,
      cellSemanticsLabel: (day, band) =>
          '${_days[day]} de ${_bands[band].toLowerCase()}',
      selected: _selected,
      onChanged: (next) => setState(() => _selected = next),
    ),
  );
}
