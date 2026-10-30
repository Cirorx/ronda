import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/widgets/onboarding_labels.dart';

/// Labels for ids as the server stores them; an unknown id shows as is.
extension AdminLabels on AppLocalizations {
  /// "El Pinar Norte" for `el-pinar-norte`.
  String barrioOf(String id) => switch (Barrio.fromId(id)) {
    final known? => barrio(known),
    null => id,
  };

  /// "Sábado a la tarde, martes a la noche" for slot ids.
  String slotsOf(List<String> ids) => [
    for (final id in ids)
      switch (Slot.fromId(id)) {
        final known? => slot(known),
        null => id,
      },
  ].join(', ');
}
