import 'package:profile_repository/profile_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The object a pretext needs, drawn by [RondaObjectIcon]; a walk needs
/// none.
extension PretextObject on Pretext {
  /// The pretext's object, or `null` when it has none.
  RondaObject? get object => switch (this) {
    Pretext.mate => RondaObject.mate,
    Pretext.truco => RondaObject.mazo,
    Pretext.futbol5 => RondaObject.pelota,
    Pretext.caminata => null,
  };
}

/// The object for what someone brings, drawn by [RondaObjectIcon]; "Tengo
/// ganas" is not a thing to draw.
extension BringObject on Bring {
  /// The thing brought, or `null` when it isn't one.
  RondaObject? get object => switch (this) {
    Bring.pan => RondaObject.bizcochos,
    Bring.yerba => RondaObject.mate,
    Bring.termo => RondaObject.termo,
    Bring.sillas => RondaObject.sillas,
    Bring.ensenoTruco => RondaObject.mazo,
    Bring.tengoGanas => null,
  };
}
