import 'dart:async';
import 'dart:math' as math;

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hair_app/core/theme.dart';
import 'package:hair_app/features/face_scanner/models/live_face.dart';
import 'package:hair_app/features/face_scanner/screens/camera_capture_screen.dart';
import 'package:hair_app/features/face_scanner/widgets/live_face_guide.dart';
import 'package:hair_app/features/face_scanner/widgets/live_face_mask.dart';

class PreviewCamera extends CameraPlatform {
  final frames = StreamController<CameraImageData>.broadcast();
  int created = 0;
  int disposed = 0;
  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 90,
    ),
    CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    ),
  ];
  @override
  Future<int> createCameraWithSettings(
    CameraDescription description,
    MediaSettings settings,
  ) async => ++created;
  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          640,
          480,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      );
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => Stream.multi((_) {});
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Future<void> lockCaptureOrientation(
    int cameraId,
    DeviceOrientation orientation,
  ) async {}
  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {}
  @override
  bool supportsImageStreaming() => true;
  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) => frames.stream;
  @override
  Widget buildPreview(int cameraId) =>
      const ColoredBox(color: Color(0xFF454545));
  @override
  Future<void> dispose(int cameraId) async {
    disposed++;
  }

  void emit() => frames.add(
    CameraImageData(
      format: const CameraImageFormat(
        ImageFormatGroup.bgra8888,
        raw: 1111970369,
      ),
      planes: [
        CameraImagePlane(bytes: Uint8List(4), bytesPerRow: 4, bytesPerPixel: 4),
      ],
      width: 480,
      height: 640,
    ),
  );
}

void main() {
  testWidgets(
    'full-screen camera opens immediately without a mesh and keeps capture guidance',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previous = CameraPlatform.instance;
      final camera = PreviewCamera();
      CameraPlatform.instance = camera;
      addTearDown(() async {
        CameraPlatform.instance = previous;
        await camera.frames.close();
      });
      List<Map<String, Object>> faces = [];
      var fail = false;
      const channel = MethodChannel('hair_app/live_face');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        if (fail) throw PlatformException(code: 'unavailable');
        return {'width': 480, 'height': 640, 'faces': faces};
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const CameraCaptureScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      final viewport = tester.getSize(find.byType(LiveFaceGuide));
      final oval = faceGuideOval(viewport);
      final target = Rect.fromCenter(
        center: oval.center,
        width: oval.width * .75,
        height: oval.height * .75,
      );
      final scale = math.max(viewport.width / 480, viewport.height / 640);
      final left = (viewport.width - 480 * scale) / 2;
      final top = (viewport.height - 640 * scale) / 2;
      final observation = <String, Object>{
        'x': (target.left - left) / (480 * scale),
        'y': (target.top - top) / (640 * scale),
        'width': target.width / (480 * scale),
        'height': target.height / (640 * scale),
        'yaw': 0,
        'pitch': 0,
        'roll': 0,
        'brightness': .5,
      };
      Future<void> frame() async {
        // The production stream is deliberately throttled with a monotonic clock.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          camera.emit();
        });
        await tester.pump();
        await tester.pump();
      }

      expect(viewport, const Size(390, 844));
      expect(camera.created, 1);
      expect(find.text('Take photo'), findsNothing);
      bool enabled() =>
          tester
              .widget<FloatingActionButton>(find.byType(FloatingActionButton))
              .onPressed !=
          null;
      expect(enabled(), isFalse);
      expect(find.byType(LiveFaceMask), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      faces = [observation];
      await frame();
      expect(find.byType(LiveFaceMask), findsNothing);
      expect(enabled(), isTrue);
      expect(
        tester.widget<LiveFaceGuide>(find.byType(LiveFaceGuide)).ready,
        isTrue,
      );
      faces = [
        {...observation, 'yaw': 30},
      ];
      await frame();
      expect(enabled(), isFalse);
      expect(
        tester.widget<LiveFaceGuide>(find.byType(LiveFaceGuide)).ready,
        isFalse,
      );
      faces = [];
      await frame();
      expect(find.byType(LiveFaceMask), findsNothing);
      faces = [observation, observation];
      await frame();
      expect(find.byType(LiveFaceMask), findsNothing);
      faces = [observation];
      await frame();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(LiveFaceMask), findsNothing);
      expect(enabled(), isFalse);
      await frame();
      await tester.tap(find.byTooltip('Switch camera'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(LiveFaceMask), findsNothing);
      expect(camera.created, 2);
      expect(camera.disposed, 1);
      fail = true;
      for (var i = 0; i < 3; i++) {
        await frame();
      }
      expect(find.text(FaceGuidance.unavailable.message), findsOneWidget);
      expect(enabled(), isTrue);
      expect(find.byType(LiveFaceMask), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
