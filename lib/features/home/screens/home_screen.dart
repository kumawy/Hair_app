import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hair_app/shared/widgets/fading_app_bar.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../hairstyles/providers/provider_hairstyle.dart';
import '../../hairstyles/providers/recommended_hairstyles_provider.dart';
import '../../../shared/widgets/hairstyle_card.dart';

class Home extends ConsumerWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final profile = ref.watch(userProfileProvider);
    final signedIn = ref.watch(authStateChangesProvider).valueOrNull != null;
    final personal = profile.valueOrNull?.hasHairProfile == true;
    final name = profile.valueOrNull?.name ?? '';
    Widget section(String title, String location) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
          TextButton(
            onPressed: () => context.push(location),
            style: TextButton.styleFrom(foregroundColor: colors.onSurface),
            child: Text(
              'See all',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    Widget row(bool recommended) => ref
        .watch(recommended ? recommendedHairstylesProvider : hairstylesProvider)
        .when(
          loading: () => const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(hairstylesProvider),
            child: const Text('Could not load hairstyles. Retry'),
          ),
          data: (items) => items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'No matching hairstyles yet. Explore the catalog for alternatives.',
                  ),
                )
              : SizedBox(
                  height: (size.height / 4).clamp(210.0, 280.0),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length > 6 ? 6 : items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => SizedBox(
                      width: (size.width / 2.5).clamp(150.0, 240.0),
                      child: HairstyleCard(hairstyle: items[i]),
                    ),
                  ),
                ),
        );
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FadingAppBar(
        actions: [
          IconButton(
            tooltip: signedIn ? 'Open profile' : 'Sign in',
            icon: const Icon(Icons.account_circle_rounded, size: 40),
            onPressed: () => signedIn
                ? context.go('/profile')
                : context.push('/loginscreen'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView(
        padding: FadingAppBar.contentPadding(
          context,
          const EdgeInsets.only(top: 4, bottom: 120),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Hello!' : 'Hello, $name',
                  style: theme.textTheme.headlineLarge,
                ),
                Text(
                  'Ready for a new look?',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: .35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.go('/FaceScanner'),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Analyze My Face',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: colors.onPrimary,
                                ),
                              ),
                              Text(
                                'Get personalized hairstyle recommendations',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onPrimary.withValues(alpha: .8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.arrow_circle_right_outlined,
                          color: colors.onPrimary,
                          size: 50,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (personal) ...[
            section('Recommended for you', '/recommendations'),
            row(true),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Complete your face shape, texture and length for personal recommendations.',
                  ),
                  TextButton(
                    onPressed: () => context.go('/FaceScanner'),
                    child: const Text('Build my hair profile'),
                  ),
                ],
              ),
            ),
          section('Explore hairstyles', '/search'),
          row(false),
        ],
      ),
    );
  }
}
