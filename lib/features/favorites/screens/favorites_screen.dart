import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hair_app/shared/widgets/fading_app_bar.dart';
import '../../../core/local_store.dart';
import '../../../shared/widgets/hairstyle_card.dart';
import '../../hairstyles/providers/provider_hairstyle.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final catalog = ref.watch(hairstylesProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FadingAppBar(title: const Text('Favorites')),
      body: favorites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(favoritesProvider),
            child: const Text('Could not load favorites. Retry'),
          ),
        ),
        data: (saved) => catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(hairstylesProvider),
              child: const Text('Could not load hairstyles. Retry'),
            ),
          ),
          data: (styles) {
            final ids = saved.map((e) => e['id']).toSet();
            final items = styles.where((s) => ids.contains(s.id)).toList();
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_border, size: 52),
                      const SizedBox(height: 16),
                      const Text('Save hairstyles you would like to try.'),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go('/search'),
                        child: const Text('Explore hairstyles'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return GridView.builder(
              padding: FadingAppBar.contentPadding(
                context,
                const EdgeInsets.fromLTRB(20, 12, 20, 120),
              ),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                childAspectRatio: .72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => HairstyleCard(hairstyle: items[i]),
            );
          },
        ),
      ),
    );
  }
}
