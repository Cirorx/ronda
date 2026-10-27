import 'package:ronda_ui/ronda_ui.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

/// Every [NoteBanner] variant, with the copy from the component sheet.
@widgetbook.UseCase(name: 'all variants', type: NoteBanner)
Widget allVariants(BuildContext context) => ListView(
  padding: const EdgeInsets.all(AppSpacing.unit),
  children: const [
    NoteBanner(message: 'Si te querés ir antes, decí «me tengo que ir».'),
    SizedBox(height: AppSpacing.unit),
    NoteBanner(
      variant: NoteBannerVariant.warning,
      title: 'Jueves 16:00 · lluvia 80%',
      message: 'Ráfagas de 50 km/h.',
    ),
    SizedBox(height: AppSpacing.unit),
    NoteBanner(
      variant: NoteBannerVariant.keptOnPhone,
      message: 'Queda guardado solo en este teléfono',
      icon: Icons.lock_outline,
    ),
    SizedBox(height: AppSpacing.unit),
    NoteBanner(
      variant: NoteBannerVariant.offline,
      message: 'Sin señal. Te mostramos lo último que vimos.',
    ),
  ],
);
