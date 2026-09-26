import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

class ScanPhoto {
  final Uint8List bytes;
  final String name;
  const ScanPhoto({required this.bytes, required this.name});

  static Future<ScanPhoto> fromFile(XFile file) async {
    if (await file.length() > 20 * 1024 * 1024) {
      throw const FormatException(
        'The captured photo exceeds 20 MB. Please retake it.',
      );
    }
    return ScanPhoto(bytes: await file.readAsBytes(), name: file.name);
  }
}
