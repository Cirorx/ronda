import 'package:ronda_ui/ronda_ui.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

/// Two [SeatRow]s from "Cerca tuyo".
@widgetbook.UseCase(name: 'cerca tuyo', type: SeatRow)
Widget cercaTuyo(BuildContext context) => ListView(
  padding: const EdgeInsets.all(AppSpacing.unit),
  children: [
    SeatRow(
      identifier: 'demo.mate',
      title: 'Mate en la rambla',
      availability: 'Quedan 2 lugares',
      detail: 'Solymar · jueves de tarde',
      note: 'Falta alguien que lleve bizcochos, o que tenga ganas.',
      seats: const SeatCount(
        filled: 4,
        total: 6,
        semanticsLabel: '4 de 6 anotados',
      ),
      onTap: () {},
    ),
    const SizedBox(height: AppSpacing.unit),
    SeatRow(
      identifier: 'demo.truco',
      title: 'Truco',
      availability: 'Queda 1 lugar',
      detail: 'Lagomar · martes de noche',
      onTap: () {},
    ),
  ],
);
