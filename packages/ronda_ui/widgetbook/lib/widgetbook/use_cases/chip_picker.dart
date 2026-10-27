import 'package:ronda_ui/ronda_ui.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _options = [
  ChipPickerOption(value: 'termo', label: 'Termo'),
  ChipPickerOption(value: 'pan', label: 'Pan'),
  ChipPickerOption(value: 'truco', label: 'Enseño truco'),
  ChipPickerOption(value: 'ganas', label: 'Tengo ganas'),
  ChipPickerOption(value: 'auto', label: 'Tengo auto', enabled: false),
];

/// A multi-select [ChipPicker] ("¿Qué podés llevar o enseñar?").
@widgetbook.UseCase(name: 'multi select', type: ChipPicker)
Widget multiSelect(BuildContext context) =>
    const _ChipPickerDemo(multiSelect: true);

/// A single-select [ChipPicker].
@widgetbook.UseCase(name: 'single select', type: ChipPicker)
Widget singleSelect(BuildContext context) =>
    const _ChipPickerDemo(multiSelect: false);

class _ChipPickerDemo extends StatefulWidget {
  const new({required this.multiSelect});

  final bool multiSelect;

  @override
  State<_ChipPickerDemo> createState() => _ChipPickerDemoState();
}

class _ChipPickerDemoState extends State<_ChipPickerDemo> {
  var _selected = <String>{'termo'};

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.unit),
    child: ChipPicker(
      identifier: 'demo',
      options: _options,
      selected: _selected,
      multiSelect: widget.multiSelect,
      onChanged: (next) => setState(() => _selected = next),
    ),
  );
}
