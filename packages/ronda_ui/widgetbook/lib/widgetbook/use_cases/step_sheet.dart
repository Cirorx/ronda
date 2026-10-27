import 'package:ronda_ui/ronda_ui.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _sheet = StepSheet(
  identifier: 'demo',
  title: 'No podemos usar el micrófono',
  body: 'Para grabar, dale permiso al micrófono en los ajustes del teléfono.',
  primaryLabel: 'Abrir ajustes',
  onPrimary: _noop,
  secondaryLabel: 'Prefiero tocar botones',
  onSecondary: _noop,
);

void _noop() {}

/// The [StepSheet] content, inline.
@widgetbook.UseCase(name: 'inline', type: StepSheet)
Widget inline(BuildContext context) => _sheet;

/// The [StepSheet] opened as a modal bottom sheet.
@widgetbook.UseCase(name: 'modal', type: StepSheet)
Widget modal(BuildContext context) => Center(
  child: Builder(
    builder: (context) => FilledButton(
      onPressed: () => _sheet.show<void>(context),
      child: const Text('Abrir'),
    ),
  ),
);
