import 'package:ronda_ui/ronda_ui.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

/// The weekly [RsvpBar]. Raise the text scale to see the buttons stack.
@widgetbook.UseCase(name: 'default', type: RsvpBar)
Widget rsvpBar(BuildContext context) => Padding(
  padding: const EdgeInsets.all(AppSpacing.unit),
  child: RsvpBar(
    identifier: 'demo',
    question: '¿Venís?',
    message: 'Te toca llevar el pan.',
    yesLabel: 'Voy',
    noLabel: 'Esta no',
    onYes: () {},
    onNo: () {},
  ),
);
