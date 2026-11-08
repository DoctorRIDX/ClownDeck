import 'package:flutter/material.dart';

import '../core/features.dart';
import '../core/theme.dart';
import '../widgets/brutal_box.dart';
import '../widgets/feature_tile.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const hPad = 16.0;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Header(),
                  const SizedBox(height: 20),
                  const _Banner(),
                  const SizedBox(height: 12),
                  const _StatusRow(),
                  const SizedBox(height: 28),
                  const _SectionLabel('FITUR'),
                  const SizedBox(height: 16),
                  _FeatureArea(width: constraints.maxWidth - hPad * 2),
                  const SizedBox(height: 28),
                  const _Footer(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BrutalBox(
          padding: const EdgeInsets.all(4),
          offset: 4,
          borderWidth: 3,
          color: AppColors.bg,
          child: Image.asset(
            'assets/images/icon.png',
            width: 44,
            height: 44,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'CLOWNDECK',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'DOCTORRIDX PROJECT',
                style: TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: AppColors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    // Rasio sama dengan gambar (1840x576) -> banner tampil utuh, tidak terpotong.
    return BrutalBox(
      padding: EdgeInsets.zero,
      offset: 8,
      color: AppColors.ink,
      child: AspectRatio(
        aspectRatio: 1840 / 576,
        child: Image.asset(
          'assets/images/banner.jpg',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Tag('BASE', filled: true),
        _Tag('V1.0.0'),
        _Tag('SIAP DIKEMBANGKAN'),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.filled = false});

  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? AppColors.red : AppColors.surfaceAlt,
        border: Border.all(
          color: filled ? AppColors.ink : AppColors.lightGrey,
          width: 2,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.mono,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: filled ? AppColors.ink : AppColors.lightGrey,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.red,
            border: Border.all(color: AppColors.lightGrey, width: 2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 3, color: AppColors.lightGrey)),
      ],
    );
  }
}

class _FeatureArea extends StatelessWidget {
  const _FeatureArea({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    if (features.isEmpty) {
      return const BrutalBox(
        shadowColor: AppColors.grey,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.extension_outlined, size: 40, color: AppColors.red),
              SizedBox(height: 12),
              Text(
                'BELUM ADA FITUR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Tambah fitur di lib/core/features.dart',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 12,
                  color: AppColors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    const gap = 10.0;
    final tileWidth = ((width - gap) / 2).floorToDouble();
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final feature in features)
          SizedBox(width: tileWidth, child: FeatureTile(feature: feature)),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'CLOWNDECK // DOCTORRIDX PROJECT',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.mono,
          fontSize: 11,
          letterSpacing: 1.5,
          color: AppColors.grey,
        ),
      ),
    );
  }
}
