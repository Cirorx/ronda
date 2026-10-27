import 'package:ronda_ui/ronda_ui.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

/// The [TermsNote] under the welcome doors.
@widgetbook.UseCase(name: 'default', type: TermsNote)
Widget termsNote(BuildContext context) => Center(
  child: Padding(
    padding: const EdgeInsets.all(AppSpacing.unit),
    child: TermsNote(
      identifier: 'demo',
      lead: 'Al seguir, aceptás las',
      linkLabel: 'condiciones de Ronda',
      trailing: '.',
      onLinkTap: () {},
    ),
  ),
);
