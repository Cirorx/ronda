import 'dart:async';

import 'package:flutter/services.dart';

/// {@template ronda_haptics}
/// The phone's haptics, kept for commits: "Voy" / "Esta no", "Lo tomo",
/// "Vino" / "No vino", "Elegir", "Aprobar". Never on a toggle, a scroll or
/// a navigation, so the few there are still mean something.
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
