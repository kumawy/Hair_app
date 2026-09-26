import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/face_mesh.dart';
import 'face_mesh_painter.dart';

const faceScanSweepDuration = Duration(milliseconds: 1800);

class FaceScanPreview extends StatelessWidget {
  const FaceScanPreview({
    super.key,
    required this.bytes,
    required this.scanning,
    this.mesh,
  });
  final Uint8List bytes;
  final bool scanning;
  final FaceMesh? mesh;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            const Center(child: Text('Preview unavailable.')),
      ),
      if (scanning) FaceScanOverlay(mesh: mesh),
    ],
  );
}

class FaceScanOverlay extends StatefulWidget {
  const FaceScanOverlay({super.key, this.mesh});
  final FaceMesh? mesh;
  @override
  State<FaceScanOverlay> createState() => _FaceScanOverlayState();
}

class _FaceScanOverlayState extends State<FaceScanOverlay>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: faceScanSweepDuration,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
      _sweep.value = .5;
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant FaceScanOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mesh != oldWidget.mesh &&
        !MediaQuery.disableAnimationsOf(context)) {
      _sweep.value = 0;
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: widget.mesh == null
            ? ScanPreparationPainter(_sweep)
            : FaceMeshPainter(mesh: widget.mesh!, sweep: _sweep),
      ),
    ),
  );
}

/// Immediate upload/preparation feedback, without inventing face landmarks.
class ScanPreparationPainter extends CustomPainter {
  ScanPreparationPainter(this.sweep) : super(repaint: sweep);
  final Animation<double> sweep;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final area = Rect.fromLTWH(
      size.width * .08,
      size.height * .2,
      size.width * .84,
      size.height * .49,
    );
    final x = area.left + area.width * sweep.value;
    final band = Rect.fromLTRB(x - 22, area.top, x + 22, area.bottom);
    canvas.save();
    canvas.clipRect(area);
    canvas.drawRect(
      band,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00B7FFE0), Color(0x2EB7FFE0), Color(0x00B7FFE0)],
        ).createShader(band),
    );
    canvas.drawLine(
      Offset(x, area.top),
      Offset(x, area.bottom),
      Paint()
        ..strokeWidth = 1.2
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00B7FFE0), Color(0xCCB7FFE0), Color(0x00B7FFE0)],
        ).createShader(area),
    );
    canvas.restore();
    final brackets = Path();
    const length = 16.0;
    for (final corner in [
      area.topLeft,
      area.topRight,
      area.bottomLeft,
      area.bottomRight,
    ]) {
      final dx = corner.dx == area.left ? length : -length;
      final dy = corner.dy == area.top ? length : -length;
      brackets.moveTo(corner.dx + dx, corner.dy);
      brackets.lineTo(corner.dx, corner.dy);
      brackets.lineTo(corner.dx, corner.dy + dy);
    }
    canvas.drawPath(
      brackets,
      Paint()
        ..color = const Color(0x88B7FFE0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(ScanPreparationPainter old) => old.sweep != sweep;
}
