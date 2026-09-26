import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hair_app/shared/widgets/fading_app_bar.dart';
import '../../../core/local_store.dart';
import '../../../shared/models/hair_attributes.dart';
import '../../face_scanner/models/face_analysis.dart';
import '../../hairstyles/providers/provider_hairstyle.dart';
import '../../hairstyles/services/hairstyle_recommender.dart';

class AnalysisHistoryScreen extends ConsumerWidget {
  const AnalysisHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: FadingAppBar(title: const Text('Recent results')),
    body: ref
        .watch(analysisHistoryProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(analysisHistoryProvider),
              child: const Text('Could not load history. Retry'),
            ),
          ),
          data: (items) => items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No saved results on this device yet.'),
                      TextButton(
                        onPressed: () => context.go('/FaceScanner'),
                        child: const Text('Start a scan'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: FadingAppBar.contentPadding(
                    context,
                    const EdgeInsets.all(20),
                  ),
                  children: [
                    const Text(
                      'Stored on this device. Photos are not included.',
                    ),
                    const SizedBox(height: 16),
                    for (final entry in items.reversed)
                      _HistoryEntry(entry: entry),
                  ],
                ),
        ),
  );
}

class _HistoryEntry extends ConsumerWidget {
  const _HistoryEntry({required this.entry});
  final Map<String, dynamic> entry;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    HairProfileSelection? selection;
    try {
      selection = HairProfileSelection(
        faceShape: Shape.values.byName(entry['faceShape'] as String),
        texture: HairTexture.values.byName(entry['hairTexture'] as String),
        length: HairLength.values.byName(entry['hairLength'] as String),
      );
    } catch (_) {
      /* Old or invalid entries remain removable. */
    }
    final date = DateTime.tryParse(
      entry['createdAt']?.toString() ?? '',
    )?.toLocal();
    final title = selection == null
        ? 'Unavailable result'
        : '${selection.faceShape.label} · ${selection.texture.label} · ${selection.length.label}';
    final catalogAsync = ref.watch(hairstylesProvider);
    final catalog = catalogAsync.valueOrNull;
    final matches = selection == null || catalog == null
        ? <HairstyleRecommendation>[]
        : compatibleRecommendations(catalog, selection).take(6).toList();
    return Card(
      child: ExpansionTile(
        title: Text(title),
        subtitle: Text(
          '${date == null ? '' : MaterialLocalizations.of(context).formatMediumDate(date)} · ${entry['source'] == 'photo' ? 'Photo estimate' : 'Manual selection'}',
        ),
        children: [
          for (final match in matches)
            ListTile(
              title: Text(match.hairstyle.name),
              subtitle: Text(
                [...match.reasons, ...match.considerations].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/hairstyle/${match.hairstyle.id}'),
            ),
          if (catalogAsync.isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          if (catalogAsync.hasError)
            TextButton(
              onPressed: () => ref.invalidate(hairstylesProvider),
              child: const Text('Could not load hairstyles. Retry'),
            ),
          if (matches.isEmpty &&
              !catalogAsync.isLoading &&
              !catalogAsync.hasError)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No matching hairstyles available.'),
            ),
          TextButton.icon(
            onPressed: () async {
              try {
                await ref
                    .read(analysisHistoryProvider.notifier)
                    .update(
                      (items) =>
                          items.where((e) => e['id'] != entry['id']).toList(),
                    );
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not delete result. Please try again.',
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete result'),
          ),
        ],
      ),
    );
  }
}
