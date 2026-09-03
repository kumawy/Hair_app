import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import 'dart:ui';
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Изначально выбран KZ (индекс 0)
  final List<bool> _isSelected = [true, false, false];

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Размытие заднего плана
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),

        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            context.pop();
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: Text(
          "Settings",
          style: textTheme.headlineLarge,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined, size: 28),
            title: Text(
              "Dark/Light theme",
              style: textTheme.titleMedium,
            ),
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (isDark) {
                ref.read(themeProvider.notifier).state =
                    isDark ? ThemeMode.dark : ThemeMode.light;
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language, size: 28),
            title: Text(
              "Language",
              style: textTheme.titleMedium,
            ),
            trailing: ToggleButtons(
              isSelected: _isSelected,
              onPressed: (int index) {
                setState(() {
                  for (int i = 0; i < _isSelected.length; i++) {
                    _isSelected[i] = i == index;
                  }
                });
              },
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              renderBorder: false,
              fillColor: Colors.transparent,
              selectedColor: theme.colorScheme.tertiary,
              color: textTheme.bodySmall?.color,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('KZ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('RU', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('ENG', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
