import 'package:ronda_ui/ronda_ui.dart';

/// {@template voice_waveform}
/// The voice as it records: a row of rounded bars in birome, newest at the
/// end side, one per level heard. Silence draws short bars and speech tall
/// ones, so a microphone that hears nothing shows at a glance.
///
/// Each new level slides the row along by one bar over [step], so it
/// scrolls steadily; with reduced motion the bars still follow the voice
/// but step instead of sliding. Screen readers skip it: the timer beside it
/// says "Grabando".
/// {@endtemplate}
class VoiceWaveform extends StatefulWidget {
  /// {@macro voice_waveform}
  const new({
    required this.levels,
    required this.heard,
    required this.length,
    this.step = const Duration(milliseconds: 40),
    super.key,
  });

  /// The last levels heard, newest last, each from 0 to 1.
  final List<double> levels;

  /// How many levels have been heard so far; a new one slides the row.
  final int heard;

  /// How many bars fit across.
  final int length;

  /// How long one bar's slide takes: the time between two levels.
  final Duration step;

  /// The row's height.
  static const height = 56.0;

  /// A bar's width, and the height of a silent one.
  static const barWidth = 3.0;

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  // Settled: the newest bar sits at the end.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: widget.step,
    value: 1,
  );

  @override
  void didUpdateWidget(VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.heard == oldWidget.heard) return;
    if (RondaMotion.of(context).reduced) {
      _slide.value = 1;
    } else {
      _slide.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: VoiceWaveform.height,
        width: double.infinity,
        child: ClipRect(
          child: CustomPaint(
            painter: _WaveformPainter(
              levels: widget.levels,
              length: widget.length,
              slide: _slide,
              color: Theme.of(context).colorScheme.primary,
              textDirection: Directionality.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  new({
    required this.levels,
    required this.length,
    required this.slide,
    required this.color,
    required this.textDirection,
  }) : super(repaint: slide);

  final List<double> levels;
  final int length;
  final Animation<double> slide;
  final Color color;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = VoiceWaveform.barWidth;
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final spacing = size.width / length;
    // Before it settles, the row sits one bar further along: the newest bar
    // slides in from past the end.
    final along = (1 - slide.value) * spacing;
    final middle = size.height / 2;
    final count = levels.length < length ? levels.length : length;
    final first = levels.length - count;
    for (var i = 0; i < count; i++) {
      final level = levels[first + i].clamp(0.0, 1.0);
      final slot = length - count + i;
      final fromStart = (slot + 0.5) * spacing + along;
      final x = textDirection == TextDirection.ltr
          ? fromStart
          : size.width - fromStart;
      // The caps add half a stroke at each end; a silent bar is a dot.
      final half = (size.height - stroke) * level / 2;
      canvas.drawLine(
        Offset(x, middle - half),
        Offset(x, middle + half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.levels != levels ||
      oldDelegate.length != length ||
      oldDelegate.color != color ||
      oldDelegate.textDirection != textDirection;
}
