import 'package:flutter/material.dart';

import 'face_mask_painter.dart';

/// A translucent animated mask attached to a single fresh face observation.
/// Position is interpolated between detections; the sweep repaints independently.
class LiveFaceMask extends StatefulWidget {
  const LiveFaceMask({super.key, required this.bounds, required this.ready});
  final Rect bounds;
  final bool ready;

  @override
  State<LiveFaceMask> createState() => _LiveFaceMaskState();
}

class _LiveFaceMaskState extends State<LiveFaceMask>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
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
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: TweenAnimationBuilder<Rect?>(
            tween: RectTween(begin: widget.bounds, end: widget.bounds),
            duration: duration,
            builder: (_, bounds, _) => TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: widget.ready ? const Color(0xFF66E3A0) : Colors.white,
              ),
              duration: duration,
              builder: (_, color, _) => CustomPaint(
                painter: FaceMaskPainter(
                  _sweep,
                  bounds: bounds,
                  live: true,
                  color: color!,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
