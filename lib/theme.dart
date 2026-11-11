import 'dart:ui';

import 'package:flutter/material.dart';

/// Warna ClownDeck: merah tua dan dark, nuansa liquid glass.
class C {
  static const bg = Color(0xFF0A0708);
  static const bg2 = Color(0xFF140C0D);
  static const surface = Color(0xFF1B1315);
  static const surface2 = Color(0xFF241A1C);
  static const border = Color(0xFF42262A);
  static const red = Color(0xFFC62430);
  static const redBright = Color(0xFFF2434F);
  static const redDeep = Color(0xFF6E0F15);
  static const text = Color(0xFFF5EEEE);
  static const muted = Color(0xFFA89A9B);
  static const ok = Color(0xFF55C08A);
  static const warn = Color(0xFFE0A33A);
  static const danger = Color(0xFFEF5257);
}

/// SEMUA sudut objek pakai nilai ini — tumpul, konsisten, tidak ada yang tajam.
const double kRadius = 15;
final BorderRadius kBorder = BorderRadius.circular(kRadius);

/// Gradasi dasar aplikasi (dipakai di belakang layar supaya tidak polos).
const bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [C.bg2, C.bg],
);

/// Gradien merah untuk elemen aktif/utama.
const redGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [C.redBright, C.redDeep],
);

/// Bayangan merah lembut supaya elemen terasa bercahaya.
List<BoxShadow> glow({
  Color color = C.red,
  double opacity = 0.28,
  double blur = 28,
  double spread = -4,
  Offset offset = const Offset(0, 10),
}) {
  return [
    BoxShadow(
      color: color.withValues(alpha: opacity),
      blurRadius: blur,
      spreadRadius: spread,
      offset: offset,
    ),
  ];
}

/// Kaca cair (liquid glass): blur di belakang + lapisan gradien transparan +
/// garis tepi tipis yang berpendar. Dipakai pada permukaan besar (drawer,
/// bottom sheet, dialog, kartu utama) — bukan tiap item kecil berulang,
/// supaya tetap mulus dipakai di HP.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius? radius;
  final double blur;
  final Color tint;
  final double tintOpacity;
  final Border? border;
  final List<BoxShadow>? shadow;

  const GlassSurface({
    super.key,
    required this.child,
    this.radius,
    this.blur = 18,
    this.tint = C.surface,
    this.tintOpacity = 0.6,
    this.border,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = radius ?? kBorder;
    return Container(
      decoration: BoxDecoration(borderRadius: effectiveRadius, boxShadow: shadow),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: effectiveRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tint.withValues(alpha: tintOpacity),
                  tint.withValues(alpha: tintOpacity * 0.85),
                ],
              ),
              border: border ?? Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1.1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

ThemeData buildTheme() {
  OutlineInputBorder outline(Color color, [double width = 1.2]) => OutlineInputBorder(
        borderRadius: kBorder,
        borderSide: BorderSide(color: color, width: width),
      );

  final scheme = ColorScheme.fromSeed(
    seedColor: C.red,
    brightness: Brightness.dark,
  ).copyWith(
    primary: C.red,
    onPrimary: Colors.white,
    surface: C.surface,
    onSurface: C.text,
    error: C.danger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.bg,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: C.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: kBorder),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: outline(C.border),
      enabledBorder: outline(C.border),
      focusedBorder: outline(C.red, 1.8),
      errorBorder: outline(C.danger),
      focusedErrorBorder: outline(C.danger, 1.8),
      labelStyle: const TextStyle(color: C.muted),
      hintStyle: const TextStyle(color: C.muted),
      prefixIconColor: C.muted,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C.red,
      selectionHandleColor: C.red,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.surface2,
      contentTextStyle: const TextStyle(color: C.text),
      shape: RoundedRectangleBorder(borderRadius: kBorder),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(
        borderRadius: kBorder,
        side: const BorderSide(color: C.border, width: 1.2),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: kBorder),
    ),
  );
}
