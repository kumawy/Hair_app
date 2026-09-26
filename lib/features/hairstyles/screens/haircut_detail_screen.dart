import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hair_app/shared/widgets/fading_app_bar.dart';
import '../../../shared/models/hairstyle.dart';
import '../../../shared/models/hair_attributes.dart';
import '../../../shared/widgets/favorite_button.dart';
import '../providers/provider_hairstyle.dart';
import 'hairstyle_generation_screen.dart';

class HairstyleDetailsRoute extends ConsumerWidget {
  const HairstyleDetailsRoute({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(hairstylesProvider)
      .when(
        loading: () => const Scaffold(
          extendBodyBehindAppBar: true,
          appBar: FadingAppBar(title: Text('Hairstyle')),
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Scaffold(
          extendBodyBehindAppBar: true,
          appBar: FadingAppBar(title: const Text('Hairstyle')),
          body: Center(
            child: TextButton(
              onPressed: () => ref.invalidate(hairstylesProvider),
              child: const Text('Could not load hairstyle. Retry'),
            ),
          ),
        ),
        data: (styles) {
          final matches = styles.where((style) => style.id == id);
          if (matches.isEmpty) {
            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: FadingAppBar(title: const Text('Hairstyle not found')),
              body: Center(
                child: TextButton(
                  onPressed: () => context.go('/search'),
                  child: const Text('Explore hairstyles'),
                ),
              ),
            );
          }
          return HaircutDetailsScreen(hairstyle: matches.first);
        },
      );
}

class HaircutDetailsScreen extends StatelessWidget {
  const HaircutDetailsScreen({super.key, required this.hairstyle});
  final Hairstyle hairstyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final viewport = MediaQuery.sizeOf(context);
    final contentWidth = math.min(viewport.width, 720.0);
    final photoHeight = math
        .min(contentWidth * 1.12, viewport.height * .55)
        .clamp(280.0, 560.0);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FadingAppBar(
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Center(
            child: _HeaderAction(
              child: IconButton(
                tooltip: 'Back',
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/search'),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: _HeaderAction(
              child: FavoriteButton(hairstyleId: hairstyle.id),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: photoHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            hairstyle.imageAsset,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -.8),
                            semanticLabel: hairstyle.name,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: colors.surface,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: colors.onSurface.withValues(alpha: .4),
                                size: 40,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 128,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      theme.scaffoldBackgroundColor.withValues(
                                        alpha: 0,
                                      ),
                                      theme.scaffoldBackgroundColor.withValues(
                                        alpha: .4,
                                      ),
                                      theme.scaffoldBackgroundColor,
                                    ],
                                    stops: const [0, .55, 1],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 152 + bottomInset),
                    sliver: SliverList.list(
                      children: [
                        Text(
                          hairstyle.name,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontSize: 34,
                            height: 1.12,
                            letterSpacing: -.9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          hairstyle.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 15,
                            height: 1.55,
                            color: colors.onSurface.withValues(alpha: .68),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _StyleStat(
                                icon: Icons.content_cut_rounded,
                                label: 'Maintenance',
                                value: hairstyle.maintenanceLevel,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StyleStat(
                                icon: Icons.tune_rounded,
                                label: 'Styling',
                                value: hairstyle.stylingDifficulty,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Style details',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.3,
                          ),
                        ),
                        const SizedBox(height: 14),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? .65
                                  : 1,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colors.onSurface.withValues(alpha: .06),
                            ),
                          ),
                          child: Column(
                            children: [
                              _Attributes(
                                title: 'Face shape',
                                items: hairstyle.suitableFaceShapes
                                    .map((v) => v.label)
                                    .toList(),
                              ),
                              const _AttributeDivider(),
                              _Attributes(
                                title: 'Hair texture',
                                items: hairstyle.suitableTextures
                                    .map((v) => v.label)
                                    .toList(),
                              ),
                              const _AttributeDivider(),
                              _Attributes(
                                title: 'Hair length',
                                items: hairstyle.suitableLengths
                                    .map((v) => v.label)
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.scaffoldBackgroundColor.withValues(alpha: 0),
                    theme.scaffoldBackgroundColor,
                    theme.scaffoldBackgroundColor,
                  ],
                  stops: const [0, .35, 1],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          minimumSize: const Size.fromHeight(56),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => HairstyleGenerationScreen(
                                  hairstyle: hairstyle,
                                ),
                              ),
                            ),
                        icon: const Icon(Icons.visibility_outlined, size: 21),
                        label: const Text('Preview hairstyle'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: .6),
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: .1),
        ),
      ),
      child: child,
    );
  }
}

class _StyleStat extends StatelessWidget {
  const _StyleStat({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? .65 : 1,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.onSurface.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: theme.brightness == Brightness.dark
                    ? colors.secondary
                    : colors.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _Attributes extends StatelessWidget {
  const _Attributes({required this.title, required this.items});
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 7,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: .055,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttributeDivider extends StatelessWidget {
  const _AttributeDivider();
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    indent: 16,
    endIndent: 16,
    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .055),
  );
}
