import 'dart:async';

import 'package:flutter/services.dart';

/// {@template ronda_haptics}
/// The phone's haptics, kept for commits: an answer recorded, something
/// sent or saved for others. `docs/DESIGN.md` § Motion and feel lists every
/// one; among them "Voy" / "Esta no" and the other answers through
/// `RsvpBar`, "Vino" / "No vino", "Elegir", "Aprobar y avisarles",
/// "Mandarlo", "Salir". Never on a toggle, a scroll, a navigation, a
/// cancel or a choice that changes nothing ("Sigo en la ronda"), so the
/// few there are still mean something.
///
/// Call it in the same handler that changes what is on screen, before the
/// work starts, so the tap is felt on the frame the change shows.
/// {@endtemplate}
abstract final class RondaHaptics {
  /// A light tap: the person committed to something.
  static Future<void> commit() => HapticFeedback.lightImpact();

  /// [onCommit] with [commit] felt first; `null` stays `null`, so a
  /// disabled button stays disabled.
  static VoidCallback? onCommit(VoidCallback? onCommit) {
    if (onCommit == null) return null;
    return () {
      unawaited(commit());
      onCommit();
    };
  }
}
