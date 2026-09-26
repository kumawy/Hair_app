import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative facets. Live bounds track a detected face, not a measured 3D mesh.
class FaceMaskPainter extends CustomPainter {
  FaceMaskPainter(
    this.sweep, {
    this.bounds,
    this.live = false,
    this.color = Colors.white,
  }) : super(repaint: sweep);

  final Rect? bounds;
  final bool live;
  final Color color;

  final Animation<double> sweep;

  // One half of an angular mask, mirrored at x = 50. The gaps form eye sockets.
  static const _vertices = [
    Offset(50, 3),
    Offset(24, 10),
    Offset(8, 30),
    Offset(5, 61),
    Offset(14, 98),
    Offset(33, 126),
    Offset(50, 142),
    Offset(50, 28),
    Offset(28, 40),
    Offset(50, 51),
    Offset(16, 57),
    Offset(34, 57),
    Offset(19, 69),
    Offset(36, 69),
    Offset(50, 83),
    Offset(26, 90),
    Offset(39, 92),
    Offset(50, 104),
    Offset(32, 107),
    Offset(50, 125),
  ];
  static const _facets = [
    [0, 1, 7],
    [1, 2, 8],
    [1, 8, 7],
    [7, 8, 9],
    [2, 3, 10],
    [2, 10, 8],
    [8, 10, 11],
    [8, 11, 9],
    [9, 11, 14],
    [11, 13, 14],
    [3, 12, 10],
    [3, 4, 12],
    [4, 15, 12],
    [12, 15, 13],
    [13, 15, 16],
    [13, 16, 14],
    [14, 16, 17],
    [4, 18, 15],
    [15, 18, 16],
    [16, 18, 17],
    [4, 5, 18],
    [5, 19, 18],
    [18, 19, 17],
    [5, 6, 19],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final fit = math.min(size.width / 118, size.height / 146);
    final target =
        bounds ??
        Rect.fromLTWH(
          (size.width - 100 * fit) / 2,
          (size.height - 146 * fit) / 2,
          100 * fit,
          146 * fit,
        );
    if (target.isEmpty) return;
    final scale = math.min(target.width / 100, target.height / 146);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(target.left, target.top);
    canvas.scale(target.width / 100, target.height / 146);

    // The sweep starts and ends outside the mask, so the loop has no visible jump.
    final x = -45 + sweep.value * 190;
    final band = Rect.fromLTRB(x - 38, 0, x + 38, 146);
    final glow = LinearGradient(
      colors: live
          ? [
              color.withValues(alpha: 0),
              color.withValues(alpha: .25),
              color.withValues(alpha: .95),
              color.withValues(alpha: .45),
              color.withValues(alpha: 0),
            ]
          : const [
              Color(0x00A77CFF),
              Color(0x558F5EFF),
              Color(0xFFF2E9FF),
              Color(0x889F75F8),
              Color(0x00A77CFF),
            ],
      stops: [0, 0.25, 0.5, 0.7, 1],
    ).createShader(band);
    final wire = Path();
    final edges = <String>{};
    final points = <Offset>{};

    for (final mirror in [false, true]) {
      final vertices = _vertices
          .map((p) => mirror ? Offset(100 - p.dx, p.dy) : p)
          .toList();
      final outline = Path()
        ..addPolygon([
          vertices[0],
          vertices[1],
          vertices[2],
          vertices[3],
          vertices[4],
          vertices[5],
          vertices[6],
        ], true);
      if (!live) {
        canvas.drawPath(outline, Paint()..color = const Color(0xE6090C13));
      }

      for (var i = 0; i < _facets.length; i++) {
        final triangle = _facets[i].map((index) => vertices[index]).toList();
        final path = Path()..addPolygon(triangle, true);
        final center = (triangle[0] + triangle[1] + triangle[2]) / 3;
        final light = math.exp(-math.pow((center.dx - x) / 22, 2));
        final shade = (i * 7 % 5) / 4;
        canvas.drawPath(
          path,
          Paint()
            ..color = Color.lerp(
              const Color(0xFF12161F),
              const Color(0xFF333946),
              shade,
            )!.withValues(alpha: live ? .06 : .88),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = (live ? color : const Color(0xFFBE9BF7)).withValues(
              alpha: light * (live ? .07 : .15),
            ),
        );
        for (var edge = 0; edge < 3; edge++) {
          final a = triangle[edge];
          final b = triangle[(edge + 1) % 3];
          final keys = ['${a.dx},${a.dy}', '${b.dx},${b.dy}']..sort();
          if (edges.add(keys.join(':'))) {
            wire.moveTo(a.dx, a.dy);
            wire.lineTo(b.dx, b.dy);
          }
          points.add(a);
        }
      }
    }

    canvas.drawPath(
      wire,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.65 / scale
        ..color = live ? color.withValues(alpha: .25) : const Color(0x558D95A8),
    );
    canvas.drawPath(
      wire,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8 / scale
        ..shader = glow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      wire,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 / scale
        ..shader = glow,
    );
    for (final point in points) {
      final light = math.exp(-math.pow((point.dx - x) / 16, 2));
      canvas.drawCircle(
        point,
        1.05 / scale,
        Paint()
          ..color = (live ? color : const Color(0xFFF1E5FF)).withValues(
            alpha: light * 0.9,
          ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FaceMaskPainter oldDelegate) =>
      oldDelegate.sweep != sweep ||
      oldDelegate.bounds != bounds ||
      oldDelegate.live != live ||
      oldDelegate.color != color;
}
