import 'package:ronda_ui/ronda_ui.dart';

/// {@template window_size}
/// How much room the window gives, by its width: Material's window size
/// classes, which every wide-screen layout in Ronda reads.
///
/// - [compact]: a phone, below [mediumWidth]. Every screen keeps its phone
///   layout here.
/// - [medium]: a tablet or a narrow window, from [mediumWidth]. Content sits
///   in a [ReadableColumn] instead of stretching.
/// - [expanded]: a desktop, from [expandedWidth]. The tabs move to a rail
///   and screens put their context beside the main column
///   ([PaperColumns]).
///
/// Read it with `WindowSize.of(context)` or `context.windowSize`.
/// {@endtemplate}
enum WindowSize {
  /// A phone.
  compact,

  /// A tablet or a narrow window.
  medium,

  /// A desktop.
  expanded;

  /// The narrowest a [medium] window is, in logical pixels.
  static const double mediumWidth = 600;

  /// The narrowest an [expanded] window is, in logical pixels.
  static const double expandedWidth = 840;

  /// The widest a column of text, a form or a card gets.
  static const double readableWidth = 600;

  /// The width of the context column beside the main one on [expanded].
  static const double sideWidth = 360;

  /// The size class of a window [width] logical pixels wide.
  static WindowSize forWidth(double width) => width >= expandedWidth
      ? expanded
      : width >= mediumWidth
      ? medium
      : compact;

  /// The size class of the window [context] is in.
  static WindowSize of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  /// Whether this window is wider than a phone.
  bool get isWide => this != compact;
}
