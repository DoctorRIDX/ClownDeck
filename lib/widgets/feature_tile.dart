import 'package:flutter/material.dart';

import '../core/features.dart';
import '../core/theme.dart';
import 'brutal_box.dart';

class FeatureTile extends StatelessWidget {
  const FeatureTile({super.key, required this.feature});

  final Feature feature;

  @override
  Widget build(BuildContext context) {
    return BrutalBox(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: feature.builder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.red,
              border: Border.all(color: AppColors.ink, width: 2),
            ),
            child: Icon(feature.icon, color: AppColors.ink, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            feature.title.toUpperCase(),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            feature.subtitle,
            style: const TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 12,
              color: AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
