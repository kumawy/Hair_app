import 'dart:io';
import 'package:hair_app/features/face_scanner/models/face_mesh.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hair_app/features/face_scanner/services/face_analysis_service.dart';

void main() {
  const url = String.fromEnvironment('FACE_ANALYSIS_URL');
  const runWithDefault = bool.fromEnvironment('RUN_FACE_ANALYSIS_LIVE_TEST');
  test(
    'local model accepts the app multipart request',
    () async {
      final photo = File('assets/hairstyles/textured_crop.jpeg');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      FaceMesh? mesh;
      final result = await container
          .read(faceAnalysisServiceProvider)
          .analyze(
            await photo.readAsBytes(),
            filename: photo.uri.pathSegments.last,
            onMesh: (value) => mesh = value,
          );
      expect(mesh?.points.length, 478);
      expect(mesh?.edges, isNotEmpty);
      expect(result.scores, isNotEmpty);
      expect(result.scores.containsKey(result.suggestedShape), isTrue);
    },
    skip: url.isEmpty && !runWithDefault
        ? 'Set FACE_ANALYSIS_URL to run against the local model.'
        : false,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
