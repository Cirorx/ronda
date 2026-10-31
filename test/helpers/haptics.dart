import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every haptic the widgets under test ask the platform for, as
/// the `HapticFeedbackType.*` argument, for the rest of the test.
List<String> recordHaptics(WidgetTester tester) {
  final haptics = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger
    ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return haptics;
}
