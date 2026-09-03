
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../features/home/screens/home_screen.dart';
import '../features/search/search_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/favorites/screens/favorites_screen.dart';
import '../features/profile/screens/settings_screen.dart';
import '../features/hairstyles/screens/haircut_detail_screen.dart';
import '../shared/models/hairstyle.dart';
import '../features/login_screen.dart';
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
path: '/hairstyle/:id',
builder: (context, state) {
final hairstyle = state.extra as Hairstyle;
return HaircutDetailsScreen(hairstyle: hairstyle);
},
),
    GoRoute(path: '/loginscreen',
    builder: (context, state) => const HairAvatar()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        final theme = Theme.of(context);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: theme.scaffoldBackgroundColor,
            systemNavigationBarIconBrightness:
                theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          ),
          child: Scaffold(
            extendBody: true,
            body: navigationShell,
            bottomNavigationBar: _FloatingNavBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (index) => navigationShell.goBranch(index),
            ),
          ),
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (context, state) => const Home())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/search', builder: (context, state) => const SearchScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/FaceScanner', builder: (context, state) => const Scaffold(
          ))],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/favorites', builder: (context, state) => const FavoritesScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen())],
        ),
      ],
    ),
  ],
);

class _FloatingNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({required this.currentIndex, required this.onTap});

  @override
  State<_FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<_FloatingNavBar> {
  static const _icons = [
    Icons.home_filled,
    Icons.explore_outlined,
    Icons.add_circle_outline,
    Icons.bookmark_border,
    Icons.person_outline,
  ];

  static const _circleSize = 44.0;

  final ValueNotifier<bool> _isDragging = ValueNotifier(false);
  final ValueNotifier<double> _dragX = ValueNotifier(0.0);
  final ValueNotifier<double> _dragStretch = ValueNotifier(0.0);

  final ValueNotifier<int?> _hoverIndex = ValueNotifier(null);

  double _lastDx = 0;

  @override
  void dispose() {
    _isDragging.dispose();
    _dragX.dispose();
    _dragStretch.dispose();
    _hoverIndex.dispose();
    super.dispose();
  }

  void _updateDrag(Offset localPosition, double barWidth, double deltaX) {
    final itemWidth = barWidth / _icons.length;

    final index = (localPosition.dx / itemWidth).floor().clamp(0, _icons.length - 1);
    _hoverIndex.value = index;

    final minX = itemWidth / 2;
    final maxX = barWidth - (itemWidth / 2);

    _dragX.value = localPosition.dx.clamp(minX, maxX);

    final rawStretch = (deltaX.abs() * 1.5).clamp(0.0, 15.0);
    _dragStretch.value = _dragStretch.value + (rawStretch - _dragStretch.value) * 0.4;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;
    final inactiveColor = colorScheme.onSurface.withValues(alpha: 0.45);
    final activeColor = colorScheme.onPrimary;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              final itemWidth = barWidth / _icons.length;
              final settledTargetX = itemWidth * widget.currentIndex + (itemWidth / 2);

              return GestureDetector(
                onHorizontalDragStart: (details) {
                  _lastDx = details.localPosition.dx;
                  _isDragging.value = true;
                  _updateDrag(details.localPosition, barWidth, 0);
                },
                onHorizontalDragUpdate: (details) {
                  final delta = details.localPosition.dx - _lastDx;
                  _lastDx = details.localPosition.dx;
                  _updateDrag(details.localPosition, barWidth, delta);
                },
                onHorizontalDragEnd: (details) {
                  if (_hoverIndex.value != null && _hoverIndex.value != widget.currentIndex) {
                    widget.onTap(_hoverIndex.value!);
                  }
                  _isDragging.value = false;
                  _dragStretch.value = 0.0;
                  _hoverIndex.value = null;
                },
                onHorizontalDragCancel: () {
                  _isDragging.value = false;
                  _dragStretch.value = 0.0;
                  _hoverIndex.value = null;
                },
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isDragging,
                  builder: (context, isDragging, _) {
                    return ValueListenableBuilder<double>(
                      valueListenable: _dragX,
                      builder: (context, dragX, _) {
                        return ValueListenableBuilder<double>(
                          valueListenable: _dragStretch,
                          builder: (context, dragStretch, _) {
                            final activeTargetX = isDragging ? dragX : settledTargetX;

                            return TweenAnimationBuilder<double>(
                              tween: Tween<double>(end: activeTargetX),
                              duration: isDragging ? Duration.zero : const Duration(milliseconds: 600),
                              curve: isDragging ? Curves.linear : Curves.easeOutBack,
                              builder: (context, currentX, child) {

                                double stretch;
                                if (isDragging) {
                                  stretch = dragStretch;
                                } else {
                                  final distance = (activeTargetX - currentX).abs();
                                  stretch = (distance * 0.4).clamp(0.0, 25.0);
                                }

                                return Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    // ФОНОВАЯ КАПЛЯ
                                    Positioned(
                                      left: currentX - _circleSize/1.4,
                                      top: 10,
                                      child: Container(
                                        width: _circleSize + stretch + 20,
                                        height: _circleSize - 10,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          borderRadius: BorderRadius.circular(_circleSize / 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: accent.withValues(alpha: 0.5),
                                              blurRadius: 16,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: List.generate(_icons.length, (index) {
                                        final iconCenterX = itemWidth * index + (itemWidth / 2);

                                        final distanceToIcon = (iconCenterX - currentX).abs();
                                        final focus = (1.0 - (distanceToIcon / itemWidth)).clamp(0.0, 1.0);

                                        final color = Color.lerp(inactiveColor, activeColor, focus)!;

                                        final scale = 1.0 + (0.15 * focus);

                                        // Сдвиг вверх по оси Y на 6 пикселей
                                        final translateY = -6.0 * focus;

                                        return GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            if (widget.currentIndex != index) {
                                              widget.onTap(index);
                                            }
                                          },
                                          child: SizedBox(
                                            width: itemWidth,
                                            child: Center(
                                              child: Transform.translate(
                                                offset: Offset(0, translateY),
                                                child: Transform.scale(
                                                  scale: scale,
                                                  child: Icon(_icons[index], color: color, size: 24),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}