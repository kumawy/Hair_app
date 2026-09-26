import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hair_app/shared/widgets/fading_app_bar.dart';
import '../../../shared/widgets/hairstyle_card.dart';
import '../providers/recommended_hairstyles_provider.dart';
import '../providers/provider_hairstyle.dart';

class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: FadingAppBar(title: const Text('Recommendations')),
    body: ref
        .watch(recommendedHairstylesProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(hairstylesProvider),
              child: const Text('Could not load hairstyles. Retry'),
            ),
          ),
          data: (items) => items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No matching hairstyles. Complete your profile or explore the catalog.',
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/FaceScanner'),
                        child: const Text('Face Scanner'),
                      ),
                      TextButton(
                        onPressed: () => context.go('/search'),
                        child: const Text('Explore hairstyles'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: FadingAppBar.contentPadding(
                    context,
                    const EdgeInsets.all(20),
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    childAspectRatio: .72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => HairstyleCard(hairstyle: items[i]),
                ),
        ),
  );
}
