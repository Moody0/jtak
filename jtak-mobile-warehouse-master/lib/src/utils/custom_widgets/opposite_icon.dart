import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Reusable Opposite Direction Icon Widget (Horizontally Mirrored)
/// Flips any Flutter / Phosphor icon horizontally so it faces the opposite direction.
/// ---------------------------------------------------------------------------
class OppositeIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final TextDirection? textDirection;

  const OppositeIcon(
    this.icon, {
    Key? key,
    this.size,
    this.color,
    this.semanticLabel,
    this.textDirection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: true,
      child: Icon(
        icon,
        size: size,
        color: color,
        semanticLabel: semanticLabel,
        textDirection: textDirection,
      ),
    );
  }
}
