import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/live_face.dart';

class LiveFaceFrame {
  const LiveFaceFrame(this.faces, this.size);
  final List<LiveFace> faces;
  final Size size;
}

class LiveFaceDetector {
  static const _channel = MethodChannel('hair_app/live_face');

  Future<LiveFaceFrame> detect(
    CameraImage image,
    CameraDescription camera,
  ) async {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    // iOS camera_avfoundation delivers already oriented and mirrored BGRA.
    // Android streams raw YUV; native code rotates and mirrors the bounds.
    final map = await _channel.invokeMapMethod<Object?, Object?>('detect', {
      'width': image.width,
      'height': image.height,
      'rotation': ios ? 0 : camera.sensorOrientation,
      'mirror': !ios && camera.lensDirection == CameraLensDirection.front,
      'planes': image.planes
          .map(
            (p) => {
              'bytes': p.bytes,
              'rowStride': p.bytesPerRow,
              'pixelStride': p.bytesPerPixel ?? 1,
            },
          )
          .toList(),
    });
    if (map == null) throw const FormatException('No detector response');
    return LiveFaceFrame(
      (map['faces'] as List).map((f) => LiveFace.fromMap(f as Map)).toList(),
      Size((map['width'] as num).toDouble(), (map['height'] as num).toDouble()),
    );
  }
}
