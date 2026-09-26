import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hair_app/shared/widgets/fading_app_bar.dart';

import '../models/live_face.dart';
import '../services/live_face_detector.dart';
import '../models/scan_photo.dart';
import '../widgets/live_face_guide.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({
    super.key,
    this.onCaptured,
    this.onChooseManually,
    this.onClose,
  });
  final ValueChanged<ScanPhoto>? onCaptured;
  final VoidCallback? onChooseManually;
  final VoidCallback? onClose;
  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void> _releasing = Future.value();
  final _detector = LiveFaceDetector();
  final _gate = FaceCaptureGate();
  final _clock = Stopwatch()..start();
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  int _generation = 0;
  bool _capturing = false;
  bool _processing = false;
  bool _autoCapture = false;
  int _failures = 0;
  Size _viewport = Size.zero;
  Duration _lastFrame = Duration.zero;
  Timer? _staleTimer;
  FaceGuidance _guidance = FaceGuidance.searching;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _discover();
  }

  Future<void> _discover() async {
    try {
      _cameras = await availableCameras();
      if (!mounted) return;
      if (_cameras.isEmpty) {
        setState(() => _error = 'No camera is available on this device.');
        return;
      }
      final front = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      _cameraIndex = front < 0 ? 0 : front;
      await _initialize();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the camera. Please try again.');
      }
    }
  }

  void _resetGuidance() {
    _staleTimer?.cancel();
    _gate.reset();
    _progress = 0;
    _guidance = FaceGuidance.searching;
  }

  Future<void> _initialize() async {
    if (!mounted || _cameras.isEmpty) return;
    final generation = ++_generation;
    final previous = _controller;
    setState(() {
      _controller = null;
      _error = null;
      _failures = 0;
      _resetGuidance();
    });
    await _release(previous);
    if (!mounted || generation != _generation) return;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted || generation != _generation) return;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
        _controller = null;
        await _release(controller);
        return;
      }
      // Detection and preview share a portrait coordinate space on both platforms.
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      try {
        await controller.setFlashMode(FlashMode.off);
      } on CameraException {
        // Some front cameras do not support configuring flash.
      }
      if (!mounted || generation != _generation) return;
      setState(() {});
      await _startStream(controller, generation);
    } on CameraException catch (error) {
      if (!mounted || generation != _generation) return;
      setState(
        () => _error = switch (error.code) {
          'CameraAccessDenied' ||
          'CameraAccessDeniedWithoutPrompt' ||
          'CameraAccessRestricted' =>
            'Camera access is unavailable. Allow it in system settings.',
          _ => 'Could not start the camera. Please try again.',
        },
      );
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Could not start the camera. Please try again.',
        );
      }
    }
  }

  Future<void> _startStream(CameraController controller, int generation) async {
    try {
      await controller.startImageStream(
        (image) => _onFrame(image, controller, generation),
      );
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _resetGuidance();
          _guidance = FaceGuidance.unavailable;
        });
      }
    }
  }

  Future<void> _onFrame(
    CameraImage image,
    CameraController controller,
    int generation,
  ) async {
    if (!mounted ||
        generation != _generation ||
        _capturing ||
        _processing ||
        _viewport.isEmpty ||
        _failures >= 3) {
      return;
    }
    final now = _clock.elapsed;
    if (now - _lastFrame < const Duration(milliseconds: 180)) return;
    _lastFrame = now;
    if (controller.value.deviceOrientation != DeviceOrientation.portraitUp) {
      setState(() {
        _resetGuidance();
        _guidance = FaceGuidance.portrait;
      });
      return;
    }
    _processing = true;
    final viewport = _viewport;
    try {
      final frame = await _detector.detect(image, controller.description);
      if (!mounted ||
          generation != _generation ||
          _capturing ||
          viewport != _viewport) {
        return;
      }
      // Do not turn green from a stale result or after rotating the device.
      if (_clock.elapsed - now > const Duration(milliseconds: 600) ||
          controller.value.deviceOrientation != DeviceOrientation.portraitUp) {
        setState(_resetGuidance);
        return;
      }
      _failures = 0;
      final guidance = evaluateFace(frame.faces, frame.size, viewport);
      final wasReady = _guidance == FaceGuidance.ready;
      final progress = _gate.update(
        guidance,
        frame.faces.length == 1 ? frame.faces.single.bounds : null,
        now,
      );
      setState(() {
        _guidance = guidance;
        _progress = _autoCapture ? progress : 0;
      });
      if (guidance == FaceGuidance.ready && !wasReady) {
        unawaited(HapticFeedback.selectionClick());
      }
      _staleTimer?.cancel();
      _staleTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted && generation == _generation && !_capturing) {
          setState(_resetGuidance);
        }
      });
      if (_autoCapture && progress >= 1) await _capture();
    } catch (_) {
      if (mounted && generation == _generation && !_capturing) {
        setState(() {
          _resetGuidance();
          _failures++;
          if (_failures >= 3) _guidance = FaceGuidance.unavailable;
        });
      }
    } finally {
      _processing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_controller == null && !_capturing) _initialize();
    } else {
      // A permission prompt can temporarily make the app inactive.
      if (_controller != null && !_controller!.value.isInitialized) return;
      ++_generation;
      _resetGuidance();
      final controller = _controller;
      _controller = null;
      unawaited(_release(controller));
      if (mounted) setState(() {});
    }
  }

  Future<void> _release(CameraController? controller) {
    if (controller != null) {
      _releasing = _releasing.then((_) async {
        try {
          await controller.dispose();
        } on CameraException {
          /* Already closed. */
        }
      });
    }
    return _releasing;
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (_capturing ||
        controller == null ||
        !controller.value.isInitialized ||
        (_guidance != FaceGuidance.ready &&
            _guidance != FaceGuidance.unavailable)) {
      return;
    }
    final generation = _generation;
    _staleTimer?.cancel();
    setState(() => _capturing = true);
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      if (!mounted || generation != _generation) return;
      final photo = await ScanPhoto.fromFile(await controller.takePicture());
      if (mounted && generation == _generation) {
        unawaited(HapticFeedback.lightImpact());
        if (widget.onCaptured != null) {
          widget.onCaptured!(photo);
        } else {
          Navigator.of(context).pop(photo);
        }
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Could not take the photo. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
        // A lifecycle interruption may have disposed the camera during capture.
        if (_controller == null &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          unawaited(_initialize());
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_generation;
    _staleTimer?.cancel();
    _clock.stop();
    unawaited(_release(_controller));
    super.dispose();
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final aligned = _guidance == FaceGuidance.ready;
    final canCapture =
        ready &&
        !_capturing &&
        (aligned || _guidance == FaceGuidance.unavailable);
    return PopScope(
      canPop: !_capturing,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: const Color(0xFF0B1013),
          extendBodyBehindAppBar: true,
          appBar: FadingAppBar(
            title: const Text('Face Scanner'),
            centerTitle: true,
            foregroundColor: Colors.white,
            tintColor: const Color(0xFF0B1013),
            systemOverlayStyle: SystemUiOverlayStyle.light,
            titleTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            leading: IconButton(
              tooltip: 'Close scanner',
              onPressed: _capturing ? null : _close,
              icon: const Icon(Icons.close_rounded),
            ),
            actions: [
              IconButton(
                tooltip: 'Switch camera',
                onPressed: _cameras.length > 1 && ready && !_capturing
                    ? () {
                        _cameraIndex = (_cameraIndex + 1) % _cameras.length;
                        _initialize();
                      }
                    : null,
                icon: const Icon(Icons.flip_camera_ios_outlined),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final viewport = constraints.biggest;
              if (_viewport != viewport) {
                _viewport = viewport;
                _resetGuidance();
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (ready && _error == null)
                    ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller.value.previewSize!.height,
                          height: controller.value.previewSize!.width,
                          child: CameraPreview(controller),
                        ),
                      ),
                    ),
                  if (_error == null)
                    LiveFaceGuide(ready: aligned, progress: _progress),
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.transparent,
                            Color(0xDD000000),
                          ],
                          stops: [0, .22, .62, 1],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        if (_error == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 16,
                            ),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                _capturing
                                    ? 'Taking photo…'
                                    : ready
                                    ? _guidance.message
                                    : 'Opening camera…',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: aligned
                                      ? const Color(0xFF66E3A0)
                                      : Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: _error != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(28),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.no_photography_outlined,
                                          color: Colors.white70,
                                          size: 36,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _error!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        FilledButton(
                                          onPressed: _cameras.isEmpty
                                              ? _discover
                                              : _initialize,
                                          child: const Text('Try again'),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : !ready
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : const SizedBox.expand(),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              const Text(
                                'Keep your forehead and chin visible',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Auto capture',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch.adaptive(
                                    value: _autoCapture,
                                    activeTrackColor: const Color(0xFF66E3A0),
                                    onChanged:
                                        !ready ||
                                            _capturing ||
                                            _guidance ==
                                                FaceGuidance.unavailable
                                        ? null
                                        : (value) => setState(() {
                                            _autoCapture = value;
                                            _gate.reset();
                                            _progress = 0;
                                          }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              FloatingActionButton(
                                heroTag: 'scanner-shutter',
                                tooltip: 'Take photo',
                                shape: const CircleBorder(),
                                elevation: 4,
                                backgroundColor: canCapture
                                    ? Colors.white
                                    : Colors.white24,
                                foregroundColor: const Color(0xFF10171B),
                                onPressed: canCapture ? _capture : null,
                                child: _capturing
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 25,
                                      ),
                              ),
                              const SizedBox(height: 14),
                              TextButton(
                                onPressed: _capturing
                                    ? null
                                    : widget.onChooseManually,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                ),
                                child: const Text('Choose face shape manually'),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
