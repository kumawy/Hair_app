import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hair_app/features/face_scanner/models/face_analysis.dart';
import 'package:hair_app/features/face_scanner/services/face_analysis_service.dart';
import 'package:hair_app/shared/models/hair_attributes.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> responseBody() => {
  'status': 'ok',
  'face_shape': 'oblong',
  'scores': {'oblong': 0.8, 'oval': 0.2},
};

class ClosingClient extends MockClient {
  ClosingClient(super.fn);
  bool closed = false;
  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  test(
    'sends multipart photo, maps oblong to long and closes client',
    () async {
      final client = ClosingClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'http://localhost:8000/api/predict');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data'),
        );
        expect(request.body, contains('name="photo"; filename="face.jpg"'));
        expect(request.body, contains('photo-bytes'));
        return http.Response(jsonEncode(responseBody()), 200);
      });
      final service = HttpFaceAnalysisService(
        baseUrl: 'http://localhost:8000/api/',
        clientFactory: () => client,
      );
      final result = await service.analyze(
        Uint8List.fromList(utf8.encode('photo-bytes')),
        filename: 'face.jpg',
      );
      expect(result.suggestedShape, Shape.long);
      expect(result.scores[Shape.long], 0.8);
      expect(result.isAmbiguous, isFalse);
      expect(client.closed, isTrue);
    },
  );

  test('missing configuration never sends a photo', () async {
    final service = HttpFaceAnalysisService(
      baseUrl: '',
      clientFactory: () => throw StateError('Must not create client'),
    );
    await expectLater(
      service.analyze(Uint8List(1), filename: 'x'),
      throwsA(
        isA<FaceAnalysisException>().having(
          (e) => e.message,
          'message',
          contains('manually'),
        ),
      ),
    );
  });

  for (final status in [
    'no_face',
    'multiple_faces',
    'side_face',
    'bad_image',
  ]) {
    test('server $status is an actionable failure, not a shape', () async {
      final client = ClosingClient(
        (_) async => http.Response(jsonEncode({'status': status}), 422),
      );
      final service = HttpFaceAnalysisService(
        baseUrl: 'http://localhost:8000',
        clientFactory: () => client,
      );
      await expectLater(
        service.analyze(Uint8List(1), filename: 'x'),
        throwsA(isA<FaceAnalysisException>()),
      );
      expect(client.closed, isTrue);
    });
  }

  test(
    'malformed or unsupported results cannot become a valid analysis',
    () async {
      for (final body in [
        'not JSON',
        jsonEncode({...responseBody(), 'face_shape': 'unknown'}),
        jsonEncode({
          ...responseBody(),
          'scores': {'oblong': -0.5},
        }),
        jsonEncode({
          ...responseBody(),
          'scores': {'oval': 1},
        }),
      ]) {
        final service = HttpFaceAnalysisService(
          baseUrl: 'http://localhost:8000',
          clientFactory: () =>
              MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          service.analyze(Uint8List(1), filename: 'x'),
          throwsA(
            isA<FaceAnalysisException>().having(
              (e) => e.message,
              'message',
              contains('invalid result'),
            ),
          ),
        );
      }
    },
  );

  test('timeout closes the connection and allows a new request', () async {
    final pending = Completer<http.Response>();
    final client = ClosingClient((_) => pending.future);
    final service = HttpFaceAnalysisService(
      baseUrl: 'http://localhost:8000',
      clientFactory: () => client,
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      service.analyze(Uint8List(1), filename: 'x'),
      throwsA(
        isA<FaceAnalysisException>().having(
          (e) => e.message,
          'message',
          contains('too long'),
        ),
      ),
    );
    expect(client.closed, isTrue);
    pending.complete(http.Response(jsonEncode(responseBody()), 200));
  });

  test(
    'close scores prompt review even when the leading class is unchanged',
    () {
      final analysis = FaceAnalysis.fromJson({
        'face_shape': 'oval',
        'scores': {'oval': 0.55, 'round': 0.435, 'heart': 0.015},
      });
      expect(analysis.suggestedShape, Shape.oval);
      expect(analysis.isAmbiguous, isTrue);
    },
  );
}
