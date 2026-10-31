import 'package:ronda_ui/ronda_ui.dart';

/// [child] under the person's "reduce motion" setting when [reduced], as
/// `MediaQuery.disableAnimations` reports it, without the test binding
/// shortening every framework animation the way the platform flag does.
Widget reducedMotion({required Widget child, bool reduced = true}) {
  if (!reduced) return child;
  return Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child,
    ),
  );
}
