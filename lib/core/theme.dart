import 'package:flutter/material.dart';

/// Palet neo-brutalism gelap: merah + abu-abu.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF101010);
  static const Color surface = Color(0xFF1C1C1C);
  static const Color surfaceAlt = Color(0xFF2A2A2A);
  static const Color grey = Color(0xFF9A9A9A);
  static const Color lightGrey = Color(0xFFE6E6E6);
  static const Color red = Color(0xFFE63B2E);
  static const Color darkRed = Color(0xFF640000);
  static const Color ink = Color(0xFF000000);
}

class AppTheme {
  AppTheme._();

  static const String mono = 'monospace';

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.red,
      onPrimary: AppColors.ink,
      secondary: AppColors.grey,
      surface: AppColors.surface,
      onSurface: AppColors.lightGrey,
      error: AppColors.red,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      splashFactory: NoSplash.splashFactory,
      textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: AppColors.lightGrey,
            displayColor: AppColors.lightGrey,
          ),
    );
  }
}
