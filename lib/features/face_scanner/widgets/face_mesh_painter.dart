import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/face_mesh.dart';

/// Draws in exactly the same centered BoxFit.cover space as the photograph.
class FaceMeshPainter extends CustomPainter {
  FaceMeshPainter({required this.mesh, required this.sweep})
    : super(repaint: sweep);
  final FaceMesh mesh;
  final Animation<double> sweep;

  // MediaPipe's anatomical contours (Apache-2.0), rather than long decorative
  // chords crossing cheeks, eyelids and lips. Indices refer to measured points.
  // Source: mediapipe/tasks/python/vision/face_landmarker.py
  static const anchors = [10, 234, 454, 152, 33, 263, 133, 362, 1, 61, 291];
  static const contours = [
    (0, 37),
    (0, 267),
    (7, 33),
    (7, 163),
    (10, 109),
    (10, 338),
    (13, 82),
    (13, 312),
    (14, 87),
    (14, 317),
    (17, 84),
    (17, 314),
    (21, 54),
    (21, 162),
    (33, 246),
    (37, 39),
    (39, 40),
    (40, 185),
    (46, 53),
    (52, 53),
    (52, 65),
    (54, 103),
    (55, 65),
    (58, 132),
    (58, 172),
    (61, 146),
    (61, 185),
    (63, 70),
    (63, 105),
    (66, 105),
    (66, 107),
    (67, 103),
    (67, 109),
    (78, 95),
    (78, 191),
    (80, 81),
    (80, 191),
    (81, 82),
    (84, 181),
    (87, 178),
    (88, 95),
    (88, 178),
    (91, 146),
    (91, 181),
    (93, 132),
    (93, 234),
    (127, 162),
    (127, 234),
    (133, 155),
    (133, 173),
    (136, 150),
    (136, 172),
    (144, 145),
    (144, 163),
    (145, 153),
    (148, 152),
    (148, 176),
    (149, 150),
    (149, 176),
    (152, 377),
    (153, 154),
    (154, 155),
    (157, 158),
    (157, 173),
    (158, 159),
    (159, 160),
    (160, 161),
    (161, 246),
    (249, 263),
    (249, 390),
    (251, 284),
    (251, 389),
    (263, 466),
    (267, 269),
    (269, 270),
    (270, 409),
    (276, 283),
    (282, 283),
    (282, 295),
    (284, 332),
    (285, 295),
    (288, 361),
    (288, 397),
    (291, 375),
    (291, 409),
    (293, 300),
    (293, 334),
    (296, 334),
    (296, 336),
    (297, 332),
    (297, 338),
    (308, 324),
    (308, 415),
    (310, 311),
    (310, 415),
    (311, 312),
    (314, 405),
    (317, 402),
    (318, 324),
    (318, 402),
    (321, 375),
    (321, 405),
    (323, 361),
    (323, 454),
    (356, 389),
    (356, 454),
    (362, 382),
    (362, 398),
    (365, 379),
    (365, 397),
    (373, 374),
    (373, 390),
    (374, 380),
    (377, 400),
    (378, 379),
    (378, 400),
    (380, 381),
    (381, 382),
    (384, 385),
    (384, 398),
    (385, 386),
    (386, 387),
    (387, 388),
    (388, 466),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = math.max(
      size.width / mesh.imageSize.width,
      size.height / mesh.imageSize.height,
    );
    final width = mesh.imageSize.width * scale;
    final height = mesh.imageSize.height * scale;
    final origin = Offset((size.width - width) / 2, (size.height - height) / 2);
    final points = mesh.points
        .map((p) => origin + Offset(p.dx * width, p.dy * height))
        .toList();
    final left = points.map((p) => p.dx).reduce(math.min);
    final right = points.map((p) => p.dx).reduce(math.max);
    final bandWidth = (right - left) * .18;
    final x =
        left - bandWidth * 2 + sweep.value * (right - left + bandWidth * 4);
    final wire = Path();
    for (final (a, b) in mesh.edges) {
      wire.moveTo(points[a].dx, points[a].dy);
      wire.lineTo(points[b].dx, points[b].dy);
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
      wire,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .4
        ..color = const Color(0x3896E8C3),
    );
    final frame = Path();
    for (final (a, b) in contours) {
      frame.moveTo(points[a].dx, points[a].dy);
      frame.lineTo(points[b].dx, points[b].dy);
    }
    canvas.drawPath(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .75
        ..color = const Color(0xA6FFFFFF),
    );
    final shader = const LinearGradient(
      colors: [Color(0x009AFAD5), Color(0xCCBEFFE8), Color(0x009AFAD5)],
      stops: [0, .5, 1],
    ).createShader(Rect.fromLTRB(x - bandWidth, 0, x + bandWidth, size.height));
    canvas.drawPath(
      wire,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      wire,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9
        ..shader = shader,
    );
    for (final p in points.take(468)) {
      final light = math.exp(
        -math.pow((p.dx - x) / math.max(1, bandWidth * .6), 2),
      );
      if (light > .1) {
        canvas.drawCircle(
          p,
          2.4,
          Paint()
            ..color = const Color(0xFFB7FFE0).withValues(alpha: light * .32)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
      canvas.drawCircle(
        p,
        .65 + light * .65,
        Paint()
          ..color = Color.lerp(const Color(0xA68EE9BB), Colors.white, light)!,
      );
    }
    for (final index in anchors) {
      canvas.drawRect(
        Rect.fromCenter(center: points[index], width: 2.7, height: 2.7),
        Paint()..color = const Color(0xEEFFFFFF),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FaceMeshPainter old) =>
      old.mesh != mesh || old.sweep != sweep;
}
