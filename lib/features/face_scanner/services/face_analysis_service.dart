import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/face_analysis.dart';
import '../models/face_mesh.dart';
import 'face_analysis_config.dart';

final faceAnalysisServiceProvider = Provider<FaceAnalysisService>((ref) {
  return HttpFaceAnalysisService(baseUrl: faceAnalysisBaseUrl);
});

abstract interface class FaceAnalysisService {
  Future<FaceAnalysis> analyze(
    Uint8List photo, {
    required String filename,
    ValueChanged<FaceMesh>? onMesh,
  });
}

class FaceAnalysisException implements Exception {
  final String message;
  const FaceAnalysisException(this.message);
  @override
  String toString() => message;
}

class HttpFaceAnalysisService implements FaceAnalysisService {
  final String baseUrl;
  final http.Client Function() _clientFactory;
  final Duration timeout;
  final Duration landmarkTimeout;

  HttpFaceAnalysisService({
    required this.baseUrl,
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 45),
    this.landmarkTimeout = const Duration(seconds: 10),
  }) : _clientFactory = clientFactory ?? http.Client.new;

  @override
  Future<FaceAnalysis> analyze(
    Uint8List photo, {
    required String filename,
    ValueChanged<FaceMesh>? onMesh,
  }) async {
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null ||
        !base.hasAuthority ||
        !['http', 'https'].contains(base.scheme) ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const FaceAnalysisException(
        'Face analysis is not available in this build. You can choose your shape manually.',
      );
    }
    if (photo.isEmpty || photo.length > 20 * 1024 * 1024) {
      throw const FaceAnalysisException('Choose a photo smaller than 20 MB.');
    }
    final client = _clientFactory();
    try {
      // A scan needs measured geometry. Surface failures instead of silently
      // waiting for classification with an empty scan overlay.
      if (onMesh != null) {
        final mesh = await _loadMesh(base, photo, filename);
        onMesh(mesh);
      }
      final response = await (() async {
        final endpoint = base.replace(
          path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/predict',
        );
        final request = http.MultipartRequest('POST', endpoint)
          ..files.add(
            http.MultipartFile.fromBytes('photo', photo, filename: filename),
          );
        return http.Response.fromStream(await client.send(request));
      })().timeout(timeout);
      if (response.statusCode >= 500) {
        throw const FaceAnalysisException(
          'The analysis service is unavailable. Please try again.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (decoded['status'] != 'ok' || response.statusCode != 200) {
        throw FaceAnalysisException(switch (decoded['status']) {
          'no_face' => 'No face found. Use a closer, front-facing photo.',
          'multiple_faces' => 'Choose a photo with just one face.',
          'side_face' => 'Look straight at the camera and take another photo.',
          'bad_image' =>
            'This photo could not be read. Try a JPEG or PNG image.',
          _ => 'The photo could not be analyzed. Please try again.',
        });
      }
      return FaceAnalysis.fromJson(decoded);
    } on FaceAnalysisException {
      rethrow;
    } on TimeoutException {
      throw const FaceAnalysisException(
        'Analysis took too long. Please try again.',
      );
    } on FormatException {
      throw const FaceAnalysisException(
        'The analysis service returned an invalid result. Please try again.',
      );
    } catch (_) {
      throw const FaceAnalysisException(
        'Cannot reach the analysis service. Check your connection and try again.',
      );
    } finally {
      client.close();
    }
  }

  Future<FaceMesh> _loadMesh(Uri base, Uint8List photo, String filename) async {
    final client = _clientFactory();
    try {
      return await (() async {
        final request =
            http.MultipartRequest(
                'POST',
                base.replace(
                  path:
                      '${base.path.replaceFirst(RegExp(r'/+$'), '')}/landmarks',
                ),
              )
              ..files.add(
                http.MultipartFile.fromBytes(
                  'photo',
                  photo,
                  filename: filename,
                ),
              );
        final response = await http.Response.fromStream(
          await client.send(request),
        );
        if (response.statusCode == 404) {
          throw const FaceAnalysisException(
            'The scan service needs an update. Restart it on your computer, then try again.',
          );
        }
        if (response.statusCode >= 500) {
          throw const FaceAnalysisException(
            'The face scanner is temporarily unavailable. Please try again.',
          );
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) throw const FormatException();
        if (decoded['status'] != 'ok' || response.statusCode != 200) {
          throw FaceAnalysisException(switch (decoded['status']) {
            'no_face' => 'No face found. Use a closer, front-facing photo.',
            'multiple_faces' => 'Choose a photo with just one face.',
            'side_face' =>
              'Look straight at the camera and take another photo.',
            'bad_image' => 'This photo could not be read. Please retake it.',
            _ => 'Could not find facial landmarks. Please retake the photo.',
          });
        }
        return FaceMesh.fromJson(decoded);
      })().timeout(landmarkTimeout);
    } on FaceAnalysisException {
      rethrow;
    } on TimeoutException {
      throw const FaceAnalysisException(
        'The scanner is not responding. For local scanning, connect your phone and computer '
        'to the same Wi-Fi and allow Local Network access in Settings.',
      );
    } on FormatException {
      throw const FaceAnalysisException(
        'The scanner returned invalid facial landmarks. Restart the service and try again.',
      );
    } catch (_) {
      throw const FaceAnalysisException(
        'Cannot reach the scanner. For local scanning, connect your phone and computer '
        'to the same Wi-Fi and allow Local Network access in Settings.',
      );
    } finally {
      client.close();
    }
  }
}
