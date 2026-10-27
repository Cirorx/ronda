import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/load_fonts.dart';

/// Runs before every test file: loads Ronda's fonts so text, and goldens,
/// use the real faces.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadRondaFonts();
  await testMain();
}
