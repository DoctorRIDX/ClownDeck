import 'package:flutter/material.dart';

import '../theme.dart';

/// Kartu dasar bergaya kaca lembut: sudut 15px, gradien tipis, bisa bercahaya.
/// Dipakai untuk item berulang (baris list) — gradien ringan tanpa blur berat
/// supaya tetap mulus discroll.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? borderColor;
  final Color? tint;
  final Color? tint;
  final bool glowing;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.tint,
    this.tint,
    this.glowing = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = tint ?? C.surface2;
    final base2 = tint ?? C.surface;
    return Container(
      decoration: BoxDecoration(
        borderRadius: kBorder,
        boxShadow: glowing ? glow(opacity: 0.2, blur: 26) : null,
      ),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: kBorder,
          side: BorderSide(color: borderColor ?? C.border, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: kBorder,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base.withValues(alpha: 0.9), base2.withValues(alpha: 0.85)],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Kotak ikon lembut — radius 15px (bukan lingkaran), gradien tipis.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const IconBadge({super.key, required this.icon, this.color, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.redDeep.withValues(alpha: 0.55), C.surface2.withValues(alpha: 0.5)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Icon(icon, size: size * 0.5, color: color ?? C.text),
    );
  }
}

/// Tombol utama: sudut 15px, gradien merah, bercahaya.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !loading && onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRadius),
          gradient: enabled
              ? redGradient
              : LinearGradient(colors: [
                  C.redDeep.withValues(alpha: 0.4),
                  C.redDeep.withValues(alpha: 0.4),
                ]),
          boxShadow: enabled ? glow(opacity: 0.35, blur: 26, offset: const Offset(0, 8)) : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 20, color: Colors.white),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol sekunder, outline, sudut 15px.
class GhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const GhostButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: C.text,
          side: const BorderSide(color: C.border, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip kecil, mis. badge "Baru".
class SoftChip extends StatelessWidget {
  final String text;
  final Color color;
  const SoftChip({super.key, required this.text, this.color = C.red});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Logo aplikasi dengan sudut 15px (bukan lingkaran).
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadius * (size / 40).clamp(0.3, 1.0)),
      child: Image.asset('assets/logo.png', width: size, height: size, fit: BoxFit.cover),
    );
  }
}

/// App bar dengan hamburger (drawer) dan logo kecil, tanpa teks berlebih.
AppBar clownAppBar(BuildContext context, {String? title, List<Widget>? actions}) {
  return AppBar(
    titleSpacing: 0,
    title: title == null
        ? null
        : Row(
            children: [
              const AppLogo(size: 28),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
    actions: actions,
  );
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Format ukuran file: B, KB, MB, GB.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final s = v >= 100 || i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return '$s ${units[i]}';
}
