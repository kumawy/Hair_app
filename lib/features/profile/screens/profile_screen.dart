import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 10),
            Center(
              child: Text(
                "Profile",
                style: textTheme.headlineLarge,
              ),
            ),
            const SizedBox(height: 24),

            // Аватар + имя + почта
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.account_circle, color: theme.colorScheme.onSurface, size: 80),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Aslan Muratov",
                        style: textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "aslanmuratov09@gmail.com",
                        style: textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Edit Profile
            SizedBox(
              width: double.infinity,
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        "Edit Profile",
                        style: textTheme.titleMedium,
                      ),
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
              title: "Recent Analyses",
              onTap: () {},
            ),
            GlassListTile(
              icon: Icons.help_outline,
              title: "Help & Support",
              onTap: () {},
            ),
            GlassListTile(
              icon: Icons.logout,
              title: "Log Out",
              onTap: () {},
              trailing: const SizedBox.shrink(),
              color: Colors.redAccent,

            ),
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
    this.color
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
            leading: Icon(icon, color: color??theme.colorScheme.onSurface, size: 28),
            title: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(color: color??theme.colorScheme.onSurface),
            ),
            trailing: trailing ??
                Icon(Icons.chevron_right, color: theme.textTheme.bodySmall?.color),
          ),
        ),
      ),
    );
  }
}
