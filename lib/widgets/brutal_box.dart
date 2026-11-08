import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Kotak neo-brutalism: border tebal + bayangan keras (tanpa blur).
/// Ruang bayangan sudah disediakan lewat padding, jadi tidak pernah terpotong.
class BrutalBox extends StatefulWidget {
  const BrutalBox({
    super.key,
    required this.child,
    this.onTap,
    this.color = AppColors.surface,
    this.shadowColor = AppColors.red,
    this.borderColor = AppColors.lightGrey,
    this.padding = const EdgeInsets.all(16),
    this.offset = 6,
    this.borderWidth = 3,
    this.radius = 4,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color shadowColor;
  final Color borderColor;
  final EdgeInsetsGeometry padding;
  final double offset;
  final double borderWidth;
  final double radius;

  @override
  State<BrutalBox> createState() => _BrutalBoxState();
}

class _BrutalBoxState extends State<BrutalBox> {
  bool _down = false;

  void _set(bool value) {
    if (widget.onTap == null) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final shift = _down ? widget.offset : 0.0;
    final shadow = _down ? 0.0 : widget.offset;

    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      transform: Matrix4.translationValues(shift, shift, 0),
      padding: widget.padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: widget.borderColor, width: widget.borderWidth),
        boxShadow: [
          BoxShadow(
            color: widget.shadowColor,
            offset: Offset(shadow, shadow),
            blurRadius: 0,
          ),
        ],
      ),
      child: widget.child,
    );

    return Padding(
      padding: EdgeInsets.only(right: widget.offset, bottom: widget.offset),
      child: widget.onTap == null
          ? box
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              onTapDown: (_) => _set(true),
              onTapUp: (_) => _set(false),
              onTapCancel: () => _set(false),
              child: box,
            ),
    );
  }
}
