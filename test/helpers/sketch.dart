import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The [RondaSketch] drawing [scene].
Finder findSketch(RondaScene scene) => find.byWidgetPredicate(
  (widget) => widget is RondaSketch && widget.scene == scene,
);
