import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hair_app/features/face_scanner/models/face_mesh.dart';
import 'package:hair_app/features/face_scanner/services/face_analysis_service.dart';
import 'package:hair_app/features/face_scanner/widgets/face_mesh_painter.dart';
import 'package:hair_app/features/face_scanner/widgets/face_scan_preview.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> meshResponse() => {
  'status': 'ok',
  'width': 480,
  'height': 640,
  'points': List.generate(
    478,
    (i) => [.2 + (i % 20) * .03, .2 + (i ~/ 20) * .02],
  ),
  'edges': [
    [0, 1],
    [1, 2],
  ],
};

void main() {
  test(
    'delivers measured geometry before classification and preserves image coordinates',
    () async {
      final events = <String>[];
      final service = HttpFaceAnalysisService(
        baseUrl: 'http://localhost:8000',
        clientFactory: () => MockClient((request) async {
          events.add(request.url.path);
          if (request.url.path == '/landmarks') {
            return http.Response(jsonEncode(meshResponse()), 200);
          }
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'face_shape': 'oval',
              'scores': {'oval': 1},
            }),
            200,
          );
        }),
      );
      await service.analyze(
        Uint8List(1),
        filename: 'selfie.jpg',
        onMesh: (mesh) {
          events.add('overlay');
          expect(mesh.points.first, const Offset(.2, .2));
          expect(mesh.imageSize, const Size(480, 640));
        },
      );
      expect(events, ['/landmarks', 'overlay', '/predict']);
    },
  );

  test(
    'missing or invalid geometry is an explicit error, never a silent scan',
    () async {
      for (final response in [
        http.Response('Not found', 404),
        http.Response('{}', 200),
        http.Response(jsonEncode({'status': 'no_face'}), 422),
      ]) {
        final requests = <String>[];
        final service = HttpFaceAnalysisService(
          baseUrl: 'http://localhost:8000',
          clientFactory: () => MockClient((request) async {
            requests.add(request.url.path);
            return response;
          }),
        );
        await expectLater(
          service.analyze(
            Uint8List(1),
            filename: 'photo.jpg',
            onMesh: (_) => fail('No mesh expected'),
          ),
          throwsA(isA<FaceAnalysisException>()),
        );
        expect(requests, ['/landmarks']);
      }
    },
  );

  test(
    'landmark timeout stops before prediction and explains the local connection',
    () async {
      final pending = Completer<http.Response>();
      var requests = 0;
      final service = HttpFaceAnalysisService(
        baseUrl: 'http://localhost:8000',
        landmarkTimeout: const Duration(milliseconds: 5),
        clientFactory: () => MockClient((_) {
          requests++;
          return pending.future;
        }),
      );
      await expectLater(
        service.analyze(Uint8List(1), filename: 'photo.jpg', onMesh: (_) {}),
        throwsA(
          isA<FaceAnalysisException>().having(
            (e) => e.message,
            'message',
            contains('same Wi-Fi'),
          ),
        ),
      );
      expect(requests, 1);
      pending.complete(http.Response('{}', 200));
    },
  );

  testWidgets(
    'scan animates before landmarks arrive, then starts a fresh mesh pass',
    (tester) async {
      Widget overlay(FaceMesh? mesh) =>
          MaterialApp(home: FaceScanOverlay(mesh: mesh));
      await tester.pumpWidget(overlay(null));
      ScanPreparationPainter preparation() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<ScanPreparationPainter>()
          .single;
      final initial = preparation().sweep.value;
      await tester.pump(const Duration(milliseconds: 600));
      expect(preparation().sweep.value, greaterThan(initial));
      await tester.pumpWidget(overlay(FaceMesh.fromJson(meshResponse())));
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<FaceMeshPainter>()
          .single;
      expect(painter.sweep.value, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(painter.sweep.value, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('rejects invalid edge indices and non-finite coordinates', () {
    expect(
      () => FaceMesh.fromJson({
        ...meshResponse(),
        'edges': [
          [0, 999],
        ],
      }),
      throwsFormatException,
    );
    final data = meshResponse();
    (data['points'] as List)[10] = [double.nan, .3];
    expect(() => FaceMesh.fromJson(data), throwsFormatException);
  });

  testWidgets('analysis sweep moves forward and reduced motion freezes it', (
    tester,
  ) async {
    final mesh = FaceMesh.fromJson(meshResponse());
    Widget overlay({bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: FaceScanOverlay(mesh: mesh),
      ),
    );
    FaceMeshPainter painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<FaceMeshPainter>()
        .single;
    await tester.pumpWidget(overlay());
    final start = painter().sweep.value;
    await tester.pump(const Duration(milliseconds: 600));
    expect(painter().sweep.value, greaterThan(start));
    expect(painter().mesh, same(mesh));
    await tester.pumpWidget(overlay(reduced: true));
    await tester.pumpAndSettle();
    expect(painter().sweep.value, .5);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
