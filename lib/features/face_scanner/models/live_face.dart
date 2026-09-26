import 'dart:ui';

/// Coordinates are normalized to the upright, displayed (mirrored front) frame.
class LiveFace {
  const LiveFace({
    required this.bounds,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.brightness,
  });
  final Rect bounds;
  final double? yaw, pitch, roll;
  final double brightness;

  factory LiveFace.fromMap(Map<Object?, Object?> map) => LiveFace(
    bounds: Rect.fromLTWH(
      (map['x'] as num).toDouble(),
      (map['y'] as num).toDouble(),
      (map['width'] as num).toDouble(),
      (map['height'] as num).toDouble(),
    ),
    yaw: (map['yaw'] as num?)?.toDouble(),
    pitch: (map['pitch'] as num?)?.toDouble(),
    roll: (map['roll'] as num?)?.toDouble(),
    brightness: (map['brightness'] as num).toDouble(),
  );
}

enum FaceGuidance {
  searching('Position your face inside the oval'),
  multiple('Only one person in the frame'),
  closer('Move a little closer'),
  farther('Move a little farther away'),
  center('Center your face inside the oval'),
  straight('Look straight at the camera'),
  light('Move to a brighter place'),
  portrait('Hold your phone upright'),
  unavailable('Live guidance unavailable. You can take a photo manually.'),
  ready('Perfect. Hold still');

  const FaceGuidance(this.message);
  final String message;
}

Rect faceGuideOval(Size size) {
  final width = (size.width * .74).clamp(0.0, size.height * .55);
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height * .43),
    width: width,
    height: width * 1.36,
  );
}

/// Same centered BoxFit.cover transform used by the camera preview.
Rect mapFaceToPreview(Rect normalized, Size image, Size viewport) {
  final scale =
      (viewport.width / image.width) > (viewport.height / image.height)
      ? viewport.width / image.width
      : viewport.height / image.height;
  final width = image.width * scale;
  final height = image.height * scale;
  return Rect.fromLTWH(
    (viewport.width - width) / 2 + normalized.left * width,
    (viewport.height - height) / 2 + normalized.top * height,
    normalized.width * width,
    normalized.height * height,
  );
}

FaceGuidance evaluateFace(List<LiveFace> faces, Size image, Size viewport) {
  if (faces.isEmpty) return FaceGuidance.searching;
  if (faces.length != 1) return FaceGuidance.multiple;
  final face = faces.single;
  final box = mapFaceToPreview(face.bounds, image, viewport);
  final oval = faceGuideOval(viewport);
  if (box.width < oval.width * .57 || box.height < oval.height * .54) {
    return FaceGuidance.closer;
  }
  if (box.width > oval.width * .96 || box.height > oval.height * .98) {
    return FaceGuidance.farther;
  }
  if ((box.center.dx - oval.center.dx).abs() > oval.width * .12 ||
      (box.center.dy - oval.center.dy).abs() > oval.height * .12 ||
      box.left < 0 ||
      box.top < 0 ||
      box.right > viewport.width ||
      box.bottom > viewport.height) {
    return FaceGuidance.center;
  }
  if (face.yaw == null ||
      face.pitch == null ||
      face.roll == null ||
      face.yaw!.abs() > 12 ||
      face.pitch!.abs() > 12 ||
      face.roll!.abs() > 10) {
    return FaceGuidance.straight;
  }
  if (face.brightness < .18) return FaceGuidance.light;
  return FaceGuidance.ready;
}

/// Only fresh, consecutive observations can trigger a capture; animation cannot.
class FaceCaptureGate {
  Duration? _started, _last;
  Rect? _anchor;
  void reset() {
    _started = null;
    _last = null;
    _anchor = null;
  }

  double update(FaceGuidance guidance, Rect? bounds, Duration now) {
    if (guidance != FaceGuidance.ready || bounds == null) {
      reset();
      return 0;
    }
    final moved =
        _anchor != null &&
        ((bounds.center - _anchor!.center).distance > .035 ||
            (bounds.width - _anchor!.width).abs() > .04);
    if (_last == null ||
        now - _last! > const Duration(milliseconds: 600) ||
        moved) {
      _started = now;
      _anchor = bounds;
    }
    _last = now;
    return ((now - _started!).inMilliseconds / 1000).clamp(0.0, 1.0);
  }
}
