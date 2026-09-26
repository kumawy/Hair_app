import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hair_app/features/face_scanner/models/live_face.dart';

const viewport = Size(400, 700);
// Upright feed and preview have matching aspect ratios here.
const image = Size(400, 700);
LiveFace face({
  Rect bounds = const Rect.fromLTWH(.24, .235, .52, .39),
  double? yaw = 0,
  double? pitch = 0,
  double? roll = 0,
  double brightness = .5,
}) => LiveFace(
  bounds: bounds,
  yaw: yaw,
  pitch: pitch,
  roll: roll,
  brightness: brightness,
);

void main() {
  test('requires one centered, front-facing and sufficiently lit face', () {
    expect(evaluateFace([], image, viewport), FaceGuidance.searching);
    expect(
      evaluateFace([face(), face()], image, viewport),
      FaceGuidance.multiple,
    );
    expect(evaluateFace([face()], image, viewport), FaceGuidance.ready);
    expect(
      evaluateFace([face(yaw: 20)], image, viewport),
      FaceGuidance.straight,
    );
    expect(
      evaluateFace([face(pitch: -20)], image, viewport),
      FaceGuidance.straight,
    );
    expect(
      evaluateFace([face(roll: 15)], image, viewport),
      FaceGuidance.straight,
    );
    expect(
      evaluateFace([face(pitch: null)], image, viewport),
      FaceGuidance.straight,
    );
    expect(
      evaluateFace([face(brightness: .08)], image, viewport),
      FaceGuidance.light,
    );
  });

  test('gives distance and centering guidance', () {
    expect(
      evaluateFace(
        [face(bounds: const Rect.fromLTWH(.4, .35, .2, .2))],
        image,
        viewport,
      ),
      FaceGuidance.closer,
    );
    expect(
      evaluateFace(
        [face(bounds: const Rect.fromLTWH(.1, .1, .8, .65))],
        image,
        viewport,
      ),
      FaceGuidance.farther,
    );
    expect(
      evaluateFace(
        [face(bounds: const Rect.fromLTWH(.42, .235, .52, .39))],
        image,
        viewport,
      ),
      FaceGuidance.center,
    );
  });

  test('cover transform accounts for cropping on a tall phone', () {
    final mapped = mapFaceToPreview(
      const Rect.fromLTWH(.25, .25, .5, .5),
      const Size(480, 640),
      const Size(400, 800),
    );
    expect(mapped, const Rect.fromLTWH(50, 200, 300, 400));
    expect(
      mapFaceToPreview(
        const Rect.fromLTWH(0, 0, 1, 1),
        const Size(480, 640),
        const Size(400, 800),
      ),
      const Rect.fromLTWH(-100, 0, 600, 800),
    );
  });

  test(
    'requires a continuous second, resets on motion, loss and stale frames',
    () {
      final gate = FaceCaptureGate();
      final bounds = face().bounds;
      double update(
        int ms, {
        FaceGuidance guidance = FaceGuidance.ready,
        Rect? box,
      }) => gate.update(guidance, box ?? bounds, Duration(milliseconds: ms));
      expect(update(0), 0);
      expect(update(200), .2);
      expect(update(400), .4);
      expect(update(600), .6);
      expect(update(800), .8);
      expect(update(1000), 1);
      expect(update(1200, guidance: FaceGuidance.searching), 0);
      expect(update(1400), 0);
      expect(
        update(2200),
        0,
      ); // A pause in detection is not stable positioning.
      expect(update(2400), .2);
      expect(update(2600, box: bounds.shift(const Offset(.05, 0))), 0);
      gate.reset();
      expect(update(2800), 0);
    },
  );
}
