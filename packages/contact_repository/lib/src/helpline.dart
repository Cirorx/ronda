/// A line in Uruguay to call when someone needs to talk to a person now.
enum Helpline {
  /// Línea de Prevención del Suicidio, from any phone.
  suicidePrevention('0800 0767'),

  /// Línea de Prevención del Suicidio, the short number from a mobile.
  suicidePreventionMobile('*0767'),

  /// Emergencias.
  emergencies('911');

  new(this.number);

  /// The number as it is written and dialled ("0800 0767").
  final String number;
}
