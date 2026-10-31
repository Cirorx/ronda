import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The widget carrying the semantics [identifier] (a Maestro handle).
Finder byIdentifier(String identifier) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == identifier,
);

/// A progress ring inside the widget with the semantics [identifier].
Finder progressIn(String identifier) => find.descendant(
  of: byIdentifier(identifier),
  matching: find.byType(CircularProgressIndicator),
);

/// Turns the phone's own "remove animations" setting on for the rest of
/// the test: the platform flag, which both [MediaQuery] and the framework's
/// animation controllers read, not only a [MediaQuery] override.
void removeAnimations(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}
