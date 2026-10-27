import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Notifies on every event of the given stream, so
/// `GoRouter.refreshListenable` re-runs its redirect when the app's sign-in
/// state changes.
class BlocRefreshListenable extends ChangeNotifier {
  new(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
