import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_store.dart';

// Провайдер для управления состоянием темы
final themeProvider = StateNotifierProvider<ThemeController, ThemeMode>(
  (ref) => ThemeController(ref.watch(localStoreProvider)),
);

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController(this.store) : super(ThemeMode.dark) {
    _load();
  }
  final LocalStore store;
  int _version = 0;
  Future<void> _load() async {
    try {
      final saved = await store.read('theme');
      if (mounted && _version == 0) {
        state = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
      }
    } catch (_) {
      /* Keep the usable default when local storage is unavailable. */
    }
  }

  Future<void> setMode(ThemeMode value) async {
    final version = ++_version;
    await store.write('theme', value.name);
    if (mounted && version == _version) state = value;
  }
}

class AppColors {
  // Общие бренд-цвета
  static const Color primary = Color(0xFF6D35DB);
  static const Color primaryAccent = Color(0xFF8B5CF6);
  static const Color primaryLight = Color(0xFF9B7CFF);

  // Темная тема (Dark Mode)
  static const Color darkBackground = Color(0xFF0B0E13);
  static const Color darkSurface = Color(0xFF1C2126);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Colors.white60;
  static const Color darkTextHint = Colors.white38;
  static const Color darkTextMuted = Colors.white54;
  static Color darkOverlay = Colors.white.withValues(alpha: 0.08);
  static Color darkBorder = Colors.white.withValues(alpha: 0.10);
  static Color darkChipUnselected = Colors.white.withValues(alpha: 0.07);
  static Color darkChipBorder = Colors.white.withValues(alpha: 0.12);

  // Светлая тема (Light Mode)
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Colors.white;
  static const Color lightTextPrimary = Color(0xFF1A1C1E);
  static const Color lightTextSecondary = Color(0xFF42474E);
  static const Color lightTextHint = Colors.black38;
  static const Color lightTextMuted = Colors.black54;
  static Color lightOverlay = Colors.black.withValues(alpha: 0.05);
  static Color lightBorder = Colors.black.withValues(alpha: 0.1);
  static Color lightChipUnselected = Colors.black.withValues(alpha: 0.05);
  static Color lightChipBorder = Colors.black.withValues(alpha: 0.08);
}

class AppTheme {
  static ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textHint: AppColors.darkTextHint,
    textMuted: AppColors.darkTextMuted,
    overlay: AppColors.darkOverlay,
    border: AppColors.darkBorder,
    chipUnselected: AppColors.darkChipUnselected,
    chipBorder: AppColors.darkChipBorder,
  );

  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textHint: AppColors.lightTextHint,
    textMuted: AppColors.lightTextMuted,
    overlay: AppColors.lightOverlay,
    border: AppColors.lightBorder,
    chipUnselected: AppColors.lightChipUnselected,
    chipBorder: AppColors.lightChipBorder,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
    required Color textHint,
    required Color textMuted,
    required Color overlay,
    required Color border,
    required Color chipUnselected,
    required Color chipBorder,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      dividerColor: border,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primaryAccent,
        onSecondary: Colors.white,
        tertiary: AppColors.primaryLight,
        onTertiary: Colors.white,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 15),
        bodySmall: TextStyle(color: textHint, fontSize: 13),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: overlay,
        hintStyle: TextStyle(color: textHint),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: chipUnselected,
        selectedColor: AppColors.primary,
        secondarySelectedColor: AppColors.primary,
        labelStyle: TextStyle(color: textPrimary),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: chipBorder),
      ),
      iconTheme: IconThemeData(color: textPrimary),
      listTileTheme: ListTileThemeData(
        iconColor: textPrimary,
        textColor: textPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLight;
          }
          return brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[300];
        }),
      ),
    );
  }
}
