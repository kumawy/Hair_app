import 'dart:math' as math;
import 'package:flutter/material.dart';

class HairAvatar extends StatefulWidget {
  final Color skinColor;
  final Color hairColor;
  final double size;
  final bool autoPlay;

  const HairAvatar({
    super.key,
    this.skinColor = const Color(0xFF9E9E9E),
    this.hairColor = const Color(0xFF252525),
    this.size = 220,
    this.autoPlay = false,
  });

  @override
  State<HairAvatar> createState() => _HairAvatarState();
}

class _HairAvatarState extends State<HairAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleHair() {
    if (_controller.value == 0) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleHair,
      child: SizedBox(
        width: widget.size,
        height: widget.size * 1.15,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _HairAvatarPainter(
                progress: Curves.easeOutCubic.transform(
                  _controller.value,
                ),
                skinColor: widget.skinColor,
                hairColor: widget.hairColor,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HairAvatarPainter extends CustomPainter {
  final double progress;
  final Color skinColor;
  final Color hairColor;

  _HairAvatarPainter({
    required this.progress,
    required this.skinColor,
    required this.hairColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    final headWidth = size.width * 0.58;
    final headHeight = size.height * 0.68;

    final headLeft = cx - headWidth / 2;
    final headTop = size.height * 0.13;

    // ─────────────────────────────
    // Shadow
    // ─────────────────────────────

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        10,
      );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          cx,
          size.height * 0.91,
        ),
        width: headWidth * 0.75,
        height: size.height * 0.055,
      ),
      shadowPaint,
    );

    // ─────────────────────────────
    // Neck
    // ─────────────────────────────

    final neckPaint = Paint()..color = skinColor;

    final neckRect = Rect.fromLTWH(
      cx - headWidth * 0.17,
      headTop + headHeight * 0.78,
      headWidth * 0.34,
      size.height * 0.19,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        neckRect,
        Radius.circular(headWidth * 0.08),
      ),
      neckPaint,
    );

    // ─────────────────────────────
    // Ears
    // ─────────────────────────────

    final earPaint = Paint()..color = skinColor;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          headLeft + headWidth * 0.015,
          headTop + headHeight * 0.53,
        ),
        width: headWidth * 0.14,
        height: headHeight * 0.22,
      ),
      earPaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          headLeft + headWidth * 0.985,
          headTop + headHeight * 0.53,
        ),
        width: headWidth * 0.14,
        height: headHeight * 0.22,
      ),
      earPaint,
    );

    // ─────────────────────────────
    // Head
    // ─────────────────────────────

    final headPaint = Paint()..color = skinColor;

    final headRect = Rect.fromLTWH(
      headLeft,
      headTop,
      headWidth,
      headHeight,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        headRect,
        Radius.circular(headWidth * 0.43),
      ),
      headPaint,
    );

    // ─────────────────────────────
    // Minimal face
    // ─────────────────────────────

    final facePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = size.width * 0.012
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Eyes
    final eyeY = headTop + headHeight * 0.48;

    canvas.drawLine(
      Offset(
        cx - headWidth * 0.19,
        eyeY,
      ),
      Offset(
        cx - headWidth * 0.13,
        eyeY,
      ),
      facePaint,
    );

    canvas.drawLine(
      Offset(
        cx + headWidth * 0.13,
        eyeY,
      ),
      Offset(
        cx + headWidth * 0.19,
        eyeY,
      ),
      facePaint,
    );

    // Small nose
    canvas.drawLine(
      Offset(cx, eyeY + headHeight * 0.035),
      Offset(
        cx - headWidth * 0.015,
        eyeY + headHeight * 0.10,
      ),
      facePaint,
    );

    // ─────────────────────────────
    // Hair
    // ─────────────────────────────

    if (progress > 0) {
      _drawMiddlePart(
        canvas,
        size,
        cx,
        headTop,
        headWidth,
        headHeight,
      );
    }
  }

  void _drawMiddlePart(
      Canvas canvas,
      Size size,
      double cx,
      double headTop,
      double headWidth,
      double headHeight,
      ) {
    final hairPaint = Paint()
      ..color = hairColor
      ..style = PaintingStyle.fill;

    // Маска роста волос.
    //
    // При progress = 0 волосы полностью скрыты.
    // При progress = 1 полностью видны.

    canvas.save();

    final growthHeight = headHeight * progress;

    canvas.clipRect(
      Rect.fromLTWH(
        0,
        headTop - 10,
        size.width,
        growthHeight + 15,
      ),
    );

    // ─────────────────────────
    // Левая часть Middle Part
    // ─────────────────────────

    final leftHair = Path();

    leftHair.moveTo(
      cx,
      headTop + headHeight * 0.035,
    );

    leftHair.cubicTo(
      cx - headWidth * 0.07,
      headTop - headHeight * 0.04,
      cx - headWidth * 0.29,
      headTop - headHeight * 0.055,
      cx - headWidth * 0.43,
      headTop + headHeight * 0.06,
    );

    leftHair.cubicTo(
      cx - headWidth * 0.55,
      headTop + headHeight * 0.15,
      cx - headWidth * 0.55,
      headTop + headHeight * 0.32,
      cx - headWidth * 0.48,
      headTop + headHeight * 0.40,
    );

    leftHair.cubicTo(
      cx - headWidth * 0.42,
      headTop + headHeight * 0.31,
      cx - headWidth * 0.35,
      headTop + headHeight * 0.23,
      cx - headWidth * 0.25,
      headTop + headHeight * 0.16,
    );

    leftHair.cubicTo(
      cx - headWidth * 0.15,
      headTop + headHeight * 0.095,
      cx - headWidth * 0.07,
      headTop + headHeight * 0.055,
      cx,
      headTop + headHeight * 0.035,
    );

    leftHair.close();

    canvas.drawPath(leftHair, hairPaint);

    // ─────────────────────────
    // Правая часть Middle Part
    // ─────────────────────────

    final rightHair = Path();

    rightHair.moveTo(
      cx,
      headTop + headHeight * 0.035,
    );

    rightHair.cubicTo(
      cx + headWidth * 0.07,
      headTop - headHeight * 0.04,
      cx + headWidth * 0.29,
      headTop - headHeight * 0.055,
      cx + headWidth * 0.43,
      headTop + headHeight * 0.06,
    );

    rightHair.cubicTo(
      cx + headWidth * 0.55,
      headTop + headHeight * 0.15,
      cx + headWidth * 0.55,
      headTop + headHeight * 0.32,
      cx + headWidth * 0.48,
      headTop + headHeight * 0.40,
    );

    rightHair.cubicTo(
      cx + headWidth * 0.42,
      headTop + headHeight * 0.31,
      cx + headWidth * 0.35,
      headTop + headHeight * 0.23,
      cx + headWidth * 0.25,
      headTop + headHeight * 0.16,
    );

    rightHair.cubicTo(
      cx + headWidth * 0.15,
      headTop + headHeight * 0.095,
      cx + headWidth * 0.07,
      headTop + headHeight * 0.055,
      cx,
      headTop + headHeight * 0.035,
    );

    rightHair.close();

    canvas.drawPath(rightHair, hairPaint);

    // ─────────────────────────
    // Дополнительные пряди
    // ─────────────────────────

    final strandPaint = Paint()
      ..color = _darken(hairColor, 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.012
      ..strokeCap = StrokeCap.round;

    final leftStrand = Path();

    leftStrand.moveTo(
      cx - headWidth * 0.05,
      headTop + headHeight * 0.07,
    );

    leftStrand.quadraticBezierTo(
      cx - headWidth * 0.22,
      headTop + headHeight * 0.10,
      cx - headWidth * 0.36,
      headTop + headHeight * 0.29,
    );

    canvas.drawPath(
      leftStrand,
      strandPaint,
    );

    final rightStrand = Path();

    rightStrand.moveTo(
      cx + headWidth * 0.05,
      headTop + headHeight * 0.07,
    );

    rightStrand.quadraticBezierTo(
      cx + headWidth * 0.22,
      headTop + headHeight * 0.10,
      cx + headWidth * 0.36,
      headTop + headHeight * 0.29,
    );

    canvas.drawPath(
      rightStrand,
      strandPaint,
    );

    // Центральный пробор
    final partPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..strokeWidth = size.width * 0.008
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(
        cx,
        headTop + headHeight * 0.045,
      ),
      Offset(
        cx,
        headTop + headHeight * 0.16,
      ),
      partPaint,
    );

    canvas.restore();
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);

    return hsl
        .withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0),
    )
        .toColor();
  }

  @override
  bool shouldRepaint(covariant _HairAvatarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.skinColor != skinColor ||
        oldDelegate.hairColor != hairColor;
  }
}