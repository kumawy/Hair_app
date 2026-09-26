import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/live_face.dart';

class LiveFaceGuide extends StatefulWidget {
  const LiveFaceGuide({super.key, required this.ready, required this.progress});
  final bool ready;
  final double progress;
  @override
  State<LiveFaceGuide> createState() => _LiveFaceGuideState();
}

class _LiveFaceGuideState extends State<LiveFaceGuide>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = .5;
    } else {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(
          end: widget.ready ? const Color(0xFF66E3A0) : Colors.white,
        ),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        builder: (context, color, _) => TweenAnimationBuilder<double>(
          tween: Tween(end: widget.progress),
          duration:
              widget.progress == 0 || MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          builder: (context, progress, _) =>
              CustomPaint(painter: _GuidePainter(_pulse, color!, progress)),
        ),
      ),
    ),
  );
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.pulse, this.color, this.progress) : super(repaint: pulse);
  final Animation<double> pulse;
  final Color color;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final base = faceGuideOval(size);
    final breath = Curves.easeInOut.transform(pulse.value);
    final oval = Rect.fromCenter(
      center: base.center,
      width: base.width * (0.99 + breath * .02),
      height: base.height * (0.99 + breath * .02),
    );
    final cutout = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(oval);
    canvas.drawPath(
      cutout,
      Paint()..color = Colors.black.withValues(alpha: .28),
    );
    canvas.drawOval(
      oval.inflate(2 + pulse.value * 4),
      Paint()
        ..color = color.withValues(alpha: .06 + pulse.value * .09)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawOval(
      oval,
      Paint()
        ..color = color.withValues(alpha: .65 + pulse.value * .3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    if (progress > 0) {
      canvas.drawArc(
        oval.inflate(7),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.color != color || old.progress != progress || old.pulse != pulse;
}
