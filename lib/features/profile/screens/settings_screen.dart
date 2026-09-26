import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hair_app/shared/widgets/fading_app_bar.dart';
import '../../../core/theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _saving = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: FadingAppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/profile'),
        icon: const Icon(Icons.arrow_back_ios_new),
      ),
      title: Text('Settings', style: Theme.of(context).textTheme.headlineLarge),
    ),
    body: ListView(
      padding: FadingAppBar.contentPadding(
        context,
        const EdgeInsets.symmetric(horizontal: 20),
      ),
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.dark_mode_outlined, size: 28),
          title: Text(
            'Dark/Light theme',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          value: ref.watch(themeProvider) == ThemeMode.dark,
          onChanged: _saving
              ? null
              : (value) async {
                  setState(() => _saving = true);
                  try {
                    await ref
                        .read(themeProvider.notifier)
                        .setMode(value ? ThemeMode.dark : ThemeMode.light);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not save theme. Please try again.',
                          ),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
        ),
        ListTile(
          leading: const Icon(Icons.language, size: 28),
          title: Text(
            'Language',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          trailing: const Text('English'),
        ),
      ],
    ),
  );
}
