import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Blends a frosted backdrop into the original content at the bar's lower edge.
class FadingAppBarBackdrop extends StatefulWidget {
  const FadingAppBarBackdrop({super.key, this.tintColor});

  final Color? tintColor;

  @override
  State<FadingAppBarBackdrop> createState() => _FadingAppBarBackdropState();
}

class _FadingAppBarBackdropState extends State<FadingAppBarBackdrop> {
  static Future<ui.FragmentProgram>? _program;
  ui.FragmentShader? _fadeShader;

  @override
  void initState() {
    super.initState();
    if (ui.ImageFilter.isShaderFilterSupported) _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await (_program ??= ui.FragmentProgram.fromAsset(
        'shaders/fading_backdrop.frag',
      ));
      if (!mounted) return;
      setState(() => _fadeShader = program.fragmentShader());
    } catch (error) {
      // Keep the native fallback available on renderers without shader filters.
      debugPrint('App bar blur shader unavailable: $error');
    }
  }

  @override
  void dispose() {
    _fadeShader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = widget.tintColor ?? theme.scaffoldBackgroundColor;
    final opacity = theme.brightness == Brightness.dark ? .66 : .72;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shader = _fadeShader;
          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (shader != null)
                  _PositionedShaderBackdrop(
                    shader: shader,
                    pixelRatio: MediaQuery.devicePixelRatioOf(context),
                    child: const SizedBox.expand(),
                  )
                else
                  // Older renderers use narrow strips with decreasing blur.
                  // No save layer sits between these filters and the content.
                  for (var i = 0; i < 16; i++)
                    Positioned(
                      top: constraints.maxHeight * i / 16,
                      height: constraints.maxHeight / 16,
                      left: 0,
                      right: 0,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(
                            sigmaX: 20 * _strength((i + .5) / 16),
                            sigmaY: 20 * _strength((i + .5) / 16),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        for (final t in [0.0, .3, .4, .5, .6, .7, .8, .9, 1.0])
                          tint.withValues(alpha: opacity * _strength(t)),
                      ],
                      stops: const [0, .3, .4, .5, .6, .7, .8, .9, 1],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static double _strength(double position) {
    final t = ((position - .3) / .7).clamp(0.0, 1.0);
    return 1 - t * t * (3 - 2 * t);
  }
}

/// Read the position during painting: floating slivers can move without
/// rebuilding their widgets. Keep the fade aligned with that frame's bounds.
class _PositionedShaderBackdrop extends SingleChildRenderObjectWidget {
  const _PositionedShaderBackdrop({
    required this.shader,
    required this.pixelRatio,
    required super.child,
  });

  final ui.FragmentShader shader;
  final double pixelRatio;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPositionedShaderBackdrop(shader, pixelRatio);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPositionedShaderBackdrop renderObject,
  ) {
    renderObject
      ..shader = shader
      ..pixelRatio = pixelRatio
      ..markNeedsPaint();
  }
}

class _RenderPositionedShaderBackdrop extends RenderProxyBox {
  _RenderPositionedShaderBackdrop(this.shader, this.pixelRatio);

  ui.FragmentShader shader;
  double pixelRatio;

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || size.isEmpty) return;
    // The engine supplies texture dimensions at uniform indices 0 and 1.
    shader
      ..setFloat(2, size.height * pixelRatio)
      ..setFloat(3, localToGlobal(Offset.zero).dy * pixelRatio);
    final backdropLayer =
        layer as BackdropFilterLayer? ?? BackdropFilterLayer();
    // Image filters snapshot shader uniforms, so create one for this position.
    backdropLayer.filter = ui.ImageFilter.compose(
      inner: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      outer: ui.ImageFilter.shader(shader),
    );
    layer = backdropLayer;
    context.pushLayer(backdropLayer, super.paint, offset);
  }
}
