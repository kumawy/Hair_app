import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hair_app/shared/widgets/fading_app_bar.dart';

import '../../../shared/models/hairstyle.dart';

/// Offline demonstration. The result is a catalog photo, not an AI edit.
class HairstyleGenerationScreen extends StatefulWidget {
  const HairstyleGenerationScreen({super.key, required this.hairstyle});

  final Hairstyle hairstyle;

  @override
  State<HairstyleGenerationScreen> createState() =>
      _HairstyleGenerationScreenState();
}

class _HairstyleGenerationScreenState extends State<HairstyleGenerationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  Timer? _demoTimer;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    _scheduleDemoResult();
  }

  void _scheduleDemoResult() {
    _demoTimer?.cancel();
    // TODO(generation-api): Replace this demo timer and catalog photo with a
    // backend generation job using the user's selfie + selected hairstyle.
    // Add upload consent, loading/error/retry/cancel states and a real result.
    // Keep the provider API key on the backend, never in the Flutter app.
    _demoTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      _motion.stop();
      setState(() => _complete = true);
    });
  }

  void _syncMotion() {
    if (_complete || MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
    } else {
      _motion.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _restart() {
    setState(() => _complete = false);
    _motion.value = 0;
    _syncMotion();
    _scheduleDemoResult();
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FadingAppBar(title: const Text('Hairstyle preview')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: FadingAppBar.contentPadding(
                context,
                const EdgeInsets.fromLTRB(20, 12, 20, 24),
              ),
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _complete ? 'Your hairstyle preview' : 'Opening preview…',
                    style: theme.textTheme.headlineLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Text(widget.hairstyle.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          widget.hairstyle.imageAsset,
                          fit: BoxFit.cover,
                          semanticLabel:
                              'Example photo of ${widget.hairstyle.name}',
                        ),
                        IgnorePointer(
                          child: AnimatedSwitcher(
                            duration: reducedMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 600),
                            child: _complete
                                ? const SizedBox.shrink()
                                : _GenerationOverlay(
                                    animation: _motion,
                                    accent: colors.secondary,
                                    reducedMotion: reducedMotion,
                                  ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          bottom: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Style reference',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _complete
                      ? 'A reference photo of this hairstyle. Your own photo has not been edited.'
                      : 'Opening a reference photo of the selected hairstyle.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                if (_complete) ...[
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Replay preview'),
                  ),
                ] else
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GenerationOverlay extends StatelessWidget {
  const _GenerationOverlay({
    required this.animation,
    required this.accent,
    required this.reducedMotion,
  });

  final Animation<double> animation;
  final Color accent;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: .48),
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final phase = reducedMotion ? .5 : animation.value;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-3 + phase * 6, -1),
                          end: Alignment(-1 + phase * 6, 1),
                          colors: [
                            Colors.transparent,
                            accent.withValues(alpha: .35),
                            Colors.white.withValues(alpha: .14),
                            Colors.transparent,
                          ],
                          stops: const [0, .45, .55, 1],
                        ),
                      ),
                    ),
                    Center(
                      child: Transform.scale(
                        scale: 1 + .08 * (1 - (phase * 2 - 1).abs()),
                        child: child,
                      ),
                    ),
                  ],
                );
              },
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .10),
                  border: Border.all(color: Colors.white.withValues(alpha: .3)),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
