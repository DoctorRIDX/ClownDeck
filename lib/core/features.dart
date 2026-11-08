import 'package:flutter/material.dart';

/// Satu fitur = satu kartu di dashboard.
class Feature {
  const Feature({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Halaman yang dibuka waktu kartu ditekan.
  final WidgetBuilder builder;
}

/// DAFTAR FITUR - tambah fitur lu di sini, dashboard otomatis nampilin kartunya.
///
/// Contoh:
/// ```dart
/// Feature(
///   title: 'Deck',
///   subtitle: 'Kelola kartu',
///   icon: Icons.style,
///   builder: (context) => const DeckScreen(),
/// ),
/// ```
final List<Feature> features = <Feature>[];
