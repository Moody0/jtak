import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../config/themes/colors.dart';

/// ---------------------------------------------------------------------------
/// Guaranteed Right-Facing Back Icon (>) for RTL Arabic Navigation
/// ---------------------------------------------------------------------------
class JtakBackIcon extends StatelessWidget {
  final double size;
  final Color color;

  const JtakBackIcon({
    super.key,
    this.size = 19,
    this.color = kCharcoalDark,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: true,
      child: Icon(
        PhosphorIconsBold.caretLeft,
        color: color,
        size: size,
        textDirection: TextDirection.ltr,
      ),
    );
  }
}

class HeaderCircleButton extends StatelessWidget {
  final Widget? icon;
  final IconData? iconData;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;

  const HeaderCircleButton({
    super.key,
    this.icon,
    this.iconData,
    required this.onTap,
    this.size = 38,
    this.iconSize = 19,
    this.iconColor = kCharcoalDark,
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFE2E8F0),
  });

  /// Standard Back Button pointing rightward (>)
  factory HeaderCircleButton.back({
    Key? key,
    required VoidCallback onTap,
    double size = 38,
    Color backgroundColor = Colors.white,
    Color borderColor = const Color(0xFFE2E8F0),
    Color iconColor = kCharcoalDark,
  }) {
    return HeaderCircleButton(
      key: key,
      onTap: onTap,
      size: size,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      icon: JtakBackIcon(
        color: iconColor,
        size: size * 0.5,
      ),
    );
  }

  /// Standard Close Button (X)
  factory HeaderCircleButton.close({
    Key? key,
    required VoidCallback onTap,
    double size = 38,
    Color backgroundColor = Colors.white,
    Color borderColor = const Color(0xFFE2E8F0),
    Color iconColor = kCharcoalDark,
  }) {
    return HeaderCircleButton(
      key: key,
      onTap: onTap,
      size: size,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      icon: Icon(
        PhosphorIconsRegular.x,
        color: iconColor,
        size: size * 0.48,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Center(
          child: icon ??
              Icon(
                iconData ?? PhosphorIconsRegular.caretRight,
                color: iconColor,
                size: iconSize,
              ),
        ),
      ),
    );
  }
}
