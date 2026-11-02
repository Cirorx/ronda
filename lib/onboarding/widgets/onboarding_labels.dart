import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';

/// The UI words for the profile and needs values, in the app's language.
extension OnboardingLabels on AppLocalizations {
  /// "Mate en la rambla".
  String pretext(Pretext pretext) => switch (pretext) {
    Pretext.mate => pretextMate,
    Pretext.truco => pretextTruco,
    Pretext.futbol5 => pretextFutbol5,
    Pretext.caminata => pretextCaminata,
    Pretext.conga => pretextConga,
    Pretext.merienda => pretextMerienda,
    Pretext.pajaros => pretextPajaros,
  };

  /// "Mate y termo".
  String bring(Bring bring) => switch (bring) {
    Bring.pan => bringPan,
    Bring.yerba => bringYerba,
    Bring.termo => bringTermo,
    Bring.sillas => bringSillas,
    Bring.ensenoTruco => bringEnsenoTruco,
    Bring.tortasFritas => bringTortasFritas,
    Bring.tengoGanas => bringTengoGanas,
  };

  /// "Solymar Norte": a proper noun, the same in every language.
  String barrio(Barrio barrio) => barrio.label;

  /// "Montevideo".
  String barrioArea(BarrioArea area) => switch (area) {
    BarrioArea.costa => barrioAreaCosta,
    BarrioArea.montevideo => barrioAreaMontevideo,
  };

  /// "Sesenta y pico".
  String ageBand(AgeBand band) => switch (band) {
    AgeBand.from18To29 => ageBand18To29,
    AgeBand.thirties => ageBandThirties,
    AgeBand.forties => ageBandForties,
    AgeBand.fifties => ageBandFifties,
    AgeBand.sixties => ageBandSixties,
    AgeBand.seventies => ageBandSeventies,
    AgeBand.eightyPlus => ageBandEightyPlus,
  };

  /// "Lunes".
  String slotDay(SlotDay day) => switch (day) {
    SlotDay.monday => dayMonday,
    SlotDay.tuesday => dayTuesday,
    SlotDay.wednesday => dayWednesday,
    SlotDay.thursday => dayThursday,
    SlotDay.friday => dayFriday,
    SlotDay.saturday => daySaturday,
    SlotDay.sunday => daySunday,
  };

  /// "Tarde".
  String slotBand(SlotBand band) => switch (band) {
    SlotBand.morning => bandMorning,
    SlotBand.afternoon => bandAfternoon,
    SlotBand.evening => bandEvening,
  };

  /// "Martes a la tarde".
  String slot(Slot slot) {
    final day = slotDay(slot.day);
    return switch (slot.band) {
      SlotBand.morning => slotMorning(day),
      SlotBand.afternoon => slotAfternoon(day),
      SlotBand.evening => slotEvening(day),
    };
  }

  /// "Caminar mucho".
  String need(Need need) => switch (need) {
    Need.walkALot => needWalkALot,
    Need.climbStairs => needClimbStairs,
    Need.returnAfterDark => needReturnAfterDark,
    Need.noCar => needNoCar,
  };
}
