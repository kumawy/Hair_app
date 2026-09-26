import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/local_store.dart';

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.hairstyleId});
  final String hairstyleId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final selected =
        favorites.valueOrNull?.any((e) => e['id'] == hairstyleId) ?? false;
    return IconButton(
      tooltip: selected ? 'Remove from favorites' : 'Save to favorites',
      icon: Icon(selected ? Icons.favorite : Icons.favorite_border),
      onPressed: favorites.isLoading
          ? null
          : () async {
              if (favorites.hasError) {
                ref.invalidate(favoritesProvider);
                return;
              }
              try {
                await ref.read(favoritesProvider.notifier).update((items) {
                  if (items.any((e) => e['id'] == hairstyleId)) {
                    return items.where((e) => e['id'] != hairstyleId).toList();
                  }
                  return [
                    ...items,
                    {'id': hairstyleId},
                  ];
                });
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not update favorites. Please try again.',
                      ),
                    ),
                  );
                }
              }
            },
    );
  }
}
