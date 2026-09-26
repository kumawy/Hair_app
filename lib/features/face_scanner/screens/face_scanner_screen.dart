import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hair_app/shared/widgets/fading_app_bar.dart';

import '../../../shared/models/hair_attributes.dart';
import '../../../core/local_store.dart';
import '../../auth/auth_repository.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../hairstyles/providers/provider_hairstyle.dart';
import '../../hairstyles/services/hairstyle_recommender.dart';
import '../models/face_analysis.dart';
import '../models/face_mesh.dart';
import '../services/face_analysis_service.dart';
import '../models/scan_photo.dart';
import 'camera_capture_screen.dart';
import '../widgets/face_scan_preview.dart';

typedef ScannerCameraBuilder =
    Widget Function(
      ValueChanged<ScanPhoto> onCaptured,
      VoidCallback onChooseManually,
      VoidCallback onClose,
    );

final scannerCameraProvider = Provider<ScannerCameraBuilder>(
  (ref) =>
      (onCaptured, onChooseManually, onClose) => CameraCaptureScreen(
        onCaptured: onCaptured,
        onChooseManually: onChooseManually,
        onClose: onClose,
      ),
);

enum _ScanStep { photo, shape, hair, result }

class FaceScannerScreen extends ConsumerStatefulWidget {
  const FaceScannerScreen({super.key});
  @override
  ConsumerState<FaceScannerScreen> createState() => _FaceScannerScreenState();
}

class _FaceScannerScreenState extends ConsumerState<FaceScannerScreen> {
  _ScanStep _step = _ScanStep.photo;
  ScanPhoto? _photo;
  FaceAnalysis? _analysis;
  FaceMesh? _mesh;
  Shape? _shape;
  HairTexture? _texture;
  HairLength? _length;
  bool _busy = false;
  bool _analyzing = false;
  bool _saving = false;
  bool _saved = false;
  bool _prefilled = false;
  String? _error;
  String? _saveError;
  int _operation = 0;
  String? _historyId;
  String? _historyError;
  bool _recording = false;

  Future<void> _recordHistory() async {
    if (_recording) return;
    final operation = _operation;
    final owner = ref.read(localOwnerProvider);
    final collection = ref.read(analysisHistoryProvider.notifier);
    final id = _historyId ??= DateTime.now().toUtc().toIso8601String();
    final entry = <String, dynamic>{
      'id': id,
      'createdAt': id,
      'faceShape': _shape!.name,
      'hairTexture': _texture!.name,
      'hairLength': _length!.name,
      'source': _analysis != null && _shape == _analysis!.suggestedShape
          ? 'photo'
          : 'manual',
    };
    setState(() {
      _recording = true;
      _historyError = null;
    });
    try {
      await collection.update(
        (items) => [...items.where((item) => item['id'] != id), entry],
      );
    } catch (_) {
      if (mounted &&
          operation == _operation &&
          owner == ref.read(localOwnerProvider)) {
        setState(
          () => _historyError = 'Could not save this result on your device.',
        );
      }
    } finally {
      if (mounted && operation == _operation) {
        setState(() => _recording = false);
      }
    }
  }

  void _showResult() {
    setState(() => _step = _ScanStep.result);
    _recordHistory();
  }

  void _reset() {
    ++_operation;
    setState(() {
      _step = _ScanStep.photo;
      _historyId = null;
      _historyError = null;
      _recording = false;
      _photo = null;
      _mesh = null;
      _analysis = null;
      _shape = null;
      _texture = null;
      _length = null;
      _busy = false;
      _analyzing = false;
      _saving = false;
      _saved = false;
      _prefilled = false;
      _error = null;
      _saveError = null;
    });
  }

  void _acceptPhoto(ScanPhoto photo) {
    ++_operation;
    setState(() {
      _historyId = null;
      _photo = photo;
      _mesh = null;
      _analysis = null;
      _shape = null;
      _saved = false;
      _error = null;
      _saveError = null;
    });
  }

  void _retakePhoto() {
    ++_operation;
    setState(() {
      _step = _ScanStep.photo;
      _photo = null;
      _mesh = null;
      _error = null;
    });
  }

  void _chooseManually() => setState(() {
    _step = _ScanStep.shape;
    _analysis = null;
    _shape = null;
    _error = null;
  });

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _analyze() async {
    final photo = _photo;
    if (photo == null || _busy) return;
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _analyzing = true;
      _mesh = null;
      _error = null;
    });
    final scanClock = Stopwatch();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    try {
      final result = await ref
          .read(faceAnalysisServiceProvider)
          .analyze(
            photo.bytes,
            filename: photo.name,
            onMesh: (mesh) {
              if (mounted && operation == _operation) {
                scanClock.start();
                setState(() => _mesh = mesh);
              }
            },
          );
      if (!mounted || operation != _operation) return;
      // Let one visual pass finish if the model responds before the sweep does.
      // This is an animation, not a percentage of model progress.
      if (scanClock.isRunning && !reduceMotion) {
        final remaining = faceScanSweepDuration - scanClock.elapsed;
        if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      }
      if (!mounted || operation != _operation) return;
      setState(() {
        _analysis = result;
        _shape = result.suggestedShape;
        _saved = false;
        _saveError = null;
        _step = _ScanStep.shape;
      });
    } on FaceAnalysisException catch (error) {
      if (mounted && operation == _operation) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted && operation == _operation) {
        setState(() => _error = 'Analysis failed. Please try again.');
      }
    } finally {
      if (mounted && operation == _operation) {
        setState(() {
          _busy = false;
          _analyzing = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    final repository = ref.read(authRepositoryProvider);
    final uid = repository.currentUser?.uid;
    if (uid == null) return;
    final operation = _operation;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await repository.updateHairProfile(
        faceShape: _shape!,
        hairTexture: _texture!,
        hairLength: _length!,
      );
      if (!mounted ||
          operation != _operation ||
          repository.currentUser?.uid != uid) {
        return;
      }
      ref.invalidate(userProfileProvider);
      setState(() => _saved = true);
      await _recordHistory();
    } catch (_) {
      if (mounted && operation == _operation) {
        setState(
          () => _saveError =
              'Could not save your profile. Your result is still here; try again.',
        );
      }
    } finally {
      if (mounted && operation == _operation) setState(() => _saving = false);
    }
  }

  Widget _button(
    String label,
    VoidCallback? onPressed, {
    bool loading = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: ElevatedButton(
      onPressed: onPressed,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    ),
  );

  Widget _choices<T extends Enum>(
    String title,
    List<T> values,
    T? selection,
    String Function(T) label,
    ValueChanged<T> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 20),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values
            .map(
              (value) => ChoiceChip(
                key: ValueKey('scan-$title-${value.name}'),
                label: Text(label(value)),
                selected: selection == value,
                onSelected: (_) => setState(() {
                  change(value);
                  _saved = false;
                }),
              ),
            )
            .toList(),
      ),
    ],
  );

  Widget _photoStep() => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: const Color(0xFF0B1013),
      extendBodyBehindAppBar: true,
      appBar: FadingAppBar(
        title: Text(_analyzing ? 'Analyzing face' : 'Review your photo'),
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
          onPressed: _close,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          FaceScanPreview(
            bytes: _photo!.bytes,
            scanning: _analyzing,
            mesh: _mesh,
          ),
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
                    Color(0xF2000000),
                  ],
                  stops: [0, .22, .5, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Flexible(
                  flex: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_analyzing) ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _mesh == null
                                  ? 'Preparing your scan…'
                                  : 'Analyzing your face shape…',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFB7FFE0),
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const SizedBox(
                            width: 120,
                            child: LinearProgressIndicator(
                              color: Color(0xFFB7FFE0),
                              backgroundColor: Colors.white12,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          const Text(
                            'Ready for your scan?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Tap Analyze to send this photo to the analysis service. '
                            'Your photo is not saved to your profile.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFFFB4AB)),
                            ),
                          ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'scanner-retake',
                              tooltip: 'Retake photo',
                              onPressed: _busy ? null : _retakePhoto,
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                              shape: const CircleBorder(),
                              child: const Icon(Icons.camera_alt_outlined),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _busy ? null : _analyze,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB7FFE0),
                                  foregroundColor: const Color(0xFF10231D),
                                  disabledBackgroundColor: Colors.white12,
                                  disabledForegroundColor: Colors.white54,
                                  minimumSize: const Size(0, 52),
                                ),
                                child: Text(
                                  _analyzing ? 'Analyzing…' : 'Analyze photo',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : _chooseManually,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text('Choose face shape manually'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _errorText(String message) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );

  List<Widget> _shapeStep() => [
    Text(
      'Confirm your face shape',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 12),
    if (_analysis != null) ...[
      Text(
        'Suggested shape: ${_analysis!.suggestedShape.label}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      Text(
        _analysis!.isAmbiguous
            ? 'The result is unclear. Choose the closest shape or try a clearer photo.'
            : 'This is an estimate. Review it and change the shape if needed.',
      ),
    ] else
      const Text('Choose the shape that best describes your face.'),
    _choices(
      'Face shape',
      Shape.values,
      _shape,
      (v) => v.label,
      (v) => _shape = v,
    ),
    const SizedBox(height: 12),
    const Text(
      'Diamond is available as a manual choice; the current model does not detect it.',
    ),
    _button(
      'Confirm shape',
      _shape == null ? null : () => setState(() => _step = _ScanStep.hair),
    ),
    TextButton(onPressed: _retakePhoto, child: const Text('Try another photo')),
  ];

  List<Widget> _hairStep(AsyncValue<UserProfile?> profileAsync) {
    if (profileAsync.isLoading ||
        ref.watch(authStateChangesProvider).isLoading) {
      return [const Center(child: CircularProgressIndicator())];
    }
    final profile = profileAsync.valueOrNull;
    if (!_prefilled) {
      _texture ??= profile?.hairTexture;
      _length ??= profile?.hairLength;
      _prefilled = true;
    }
    return [
      if (profileAsync.hasError) ...[
        const Text(
          'Could not load your saved parameters. You can choose them below.',
        ),
        TextButton(
          onPressed: () => ref.invalidate(userProfileProvider),
          child: const Text('Retry loading profile'),
        ),
      ],
      Text(
        'Complete your hair profile',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      const Text(
        'Saved values are preselected. Fill in anything missing, or update them if your hair has changed.',
      ),
      _choices(
        'Hair texture',
        HairTexture.values,
        _texture,
        (v) => v.label,
        (v) => _texture = v,
      ),
      _choices(
        'Current length',
        HairLength.values,
        _length,
        (v) => v.label,
        (v) => _length = v,
      ),
      _button(
        'See recommendations',
        _texture == null || _length == null ? null : _showResult,
      ),
      TextButton(
        onPressed: () => setState(() => _step = _ScanStep.shape),
        child: const Text('Back to face shape'),
      ),
    ];
  }

  List<Widget> _resultStep(bool signedIn) {
    final selection = HairProfileSelection(
      faceShape: _shape!,
      texture: _texture!,
      length: _length!,
    );
    final styles = ref.watch(hairstylesProvider);
    return [
      Text(
        'Your hair profile',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(label: Text('${_shape!.label} face')),
          Chip(label: Text('${_texture!.label} hair')),
          Chip(label: Text('${_length!.label} length')),
        ],
      ),
      if (signedIn)
        _button(
          _saved ? 'Saved to profile' : 'Save to profile',
          _saving || _saved ? null : _save,
          loading: _saving,
        )
      else
        _button(
          'Sign in to save this result',
          () => context.push('/loginscreen'),
        ),
      if (_historyError != null) ...[
        _errorText(_historyError!),
        TextButton(
          onPressed: _recording
              ? null
              : () {
                  ref.invalidate(analysisHistoryProvider);
                  _recordHistory();
                },
          child: const Text('Retry saving to history'),
        ),
      ],
      if (_saveError != null) _errorText(_saveError!),
      const SizedBox(height: 28),
      Text(
        'Recommended for you',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'Matches your face shape and texture in our catalog. Some styles may require growing or cutting your hair. Discuss the final cut with your barber.',
      ),
      const SizedBox(height: 16),
      styles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(hairstylesProvider),
          child: const Text('Could not load hairstyles. Retry'),
        ),
        data: (catalog) {
          if (catalog.isEmpty) {
            return const Text('No hairstyles are available yet.');
          }
          final ranked = compatibleRecommendations(catalog, selection).take(6);
          if (ranked.isEmpty) {
            return const Text(
              'No matching hairstyles in this catalog yet. Explore the catalog for other ideas.',
            );
          }
          return Column(children: ranked.map(_recommendationCard).toList());
        },
      ),
      TextButton(
        onPressed: _saving
            ? null
            : () => setState(() {
                _step = _ScanStep.hair;
                _saveError = null;
              }),
        child: const Text('Edit parameters'),
      ),
      TextButton(
        onPressed: _saving ? null : _reset,
        child: const Text('Start a new scan'),
      ),
    ];
  }

  Widget _recommendationCard(HairstyleRecommendation item) {
    final style = item.hairstyle;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/hairstyle/${style.id}', extra: style),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      style.imageAsset,
                      width: 72,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${style.maintenanceLevel} maintenance · ${style.stylingDifficulty} styling',
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              for (final reason in item.reasons) Text('✓ $reason'),
              for (final consideration in item.considerations)
                Text(
                  consideration,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateChangesProvider, (previous, next) {
      if (previous?.valueOrNull != null &&
          next.hasValue &&
          previous?.valueOrNull?.uid != next.valueOrNull?.uid) {
        _reset();
      }
    });
    if (_step == _ScanStep.photo) {
      return _photo == null
          ? ref.watch(scannerCameraProvider)(
              _acceptPhoto,
              _chooseManually,
              _close,
            )
          : _photoStep();
    }
    final profileAsync = ref.watch(userProfileProvider);
    final signedIn = ref.watch(authStateChangesProvider).valueOrNull != null;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FadingAppBar(
        title: const Text('Face Scanner'),
        leading: IconButton(
          tooltip: 'Close scanner',
          onPressed: _close,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: ValueKey(_step),
          padding: FadingAppBar.contentPadding(
            context,
            const EdgeInsets.fromLTRB(20, 8, 20, 120),
          ),
          children: [
            LinearProgressIndicator(
              value: (_step.index + 1) / _ScanStep.values.length,
            ),
            const SizedBox(height: 20),
            ...switch (_step) {
              _ScanStep.photo => const <Widget>[],
              _ScanStep.shape => _shapeStep(),
              _ScanStep.hair => _hairStep(profileAsync),
              _ScanStep.result => _resultStep(signedIn),
            },
          ],
        ),
      ),
    );
  }
}
