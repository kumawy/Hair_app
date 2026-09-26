import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hair_app/shared/widgets/fading_app_bar.dart';

import '../../auth/auth_repository.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../../shared/models/hair_attributes.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not sign out. Please try again.'),
          ),
        );
      }
      return;
    }

    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const FadingAppBar(title: Text('Profile'), centerTitle: true),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: FadingAppBar.contentPadding(
            context,
            const EdgeInsets.fromLTRB(20, 24, 20, 0),
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_circle,
                  color: theme.colorScheme.onSurface,
                  size: 80,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: profileAsync.when(
                    loading: () =>
                        Text('Loading...', style: textTheme.titleLarge),
                    error: (error, stackTrace) => Text(
                      'Failed to load profile',
                      style: textTheme.titleLarge,
                    ),
                    data: (profile) {
                      if (profile == null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Not signed in', style: textTheme.titleLarge),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: () => context.push('/loginscreen'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text('Sign in'),
                            ),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            profile.fullName.isNotEmpty
                                ? profile.fullName
                                : profile.email,
                            style: textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.fullName.isNotEmpty
                                ? profile.email
                                : 'Complete your profile',
                            style: textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            profileAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => TextButton(
                onPressed: () => ref.invalidate(userProfileProvider),
                child: const Text('Retry loading profile'),
              ),
              data: (profile) {
                if (profile == null) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      spacing: 10,
                      children: [
                        Icon(
                          Icons.face_outlined,
                          color: theme.colorScheme.onSurface,
                          size: 28,
                        ),
                        Text(
                          profile.faceShape?.label ?? 'Face shape not set',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      spacing: 10,
                      children: [
                        Icon(
                          Icons.straighten,
                          color: theme.colorScheme.onSurface,
                          size: 28,
                        ),
                        Text(
                          profile.hairTexture?.label ?? 'Hair texture not set',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      spacing: 10,
                      children: [
                        Icon(
                          Icons.content_cut_outlined,
                          color: theme.colorScheme.onSurface,
                          size: 28,
                        ),
                        Text(
                          profile.hairLength?.label ?? 'Hair length not set',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    context.push('/editprofile');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text("Edit Profile", style: textTheme.titleMedium),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            GlassListTile(
              icon: Icons.settings,
              title: "Settings",
              onTap: () {
                context.push('/settings');
              },
            ),
            GlassListTile(
              icon: Icons.history,
              title: "Recent Results",
              onTap: () => context.push('/history'),
            ),
            GlassListTile(
              icon: Icons.help_outline,
              title: "Help",
              onTap: () => context.push('/help'),
            ),
            if (ref.watch(authStateChangesProvider).valueOrNull != null)
              GlassListTile(
                icon: Icons.logout,
                title: "Log Out",
                onTap: () => _logOut(context, ref),
                trailing: const SizedBox.shrink(),
                color: Colors.redAccent,
              )
            else
              const SizedBox(height: 10),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

class GlassListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? color;

  const GlassListTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(20);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: radius,
        border: Border.all(
          color: color ?? theme.dividerColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ListTile(
            leading: Icon(
              icon,
              color: color ?? theme.colorScheme.onSurface,
              size: 28,
            ),
            title: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color ?? theme.colorScheme.onSurface,
              ),
            ),
            trailing:
                trailing ??
                Icon(
                  Icons.chevron_right,
                  color: theme.textTheme.bodySmall?.color,
                ),
          ),
        ),
      ),
    );
  }
}
