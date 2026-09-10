import 'package:flutter/material.dart';

import '../../config/themes/app_theme.dart';
import '../../config/themes/colors.dart';

class CustomBadge extends StatelessWidget {
  final Widget child;
  final int value;
  final Color backgroundColor;
  final Color textColor;
  final double right;
  final double top;

  const CustomBadge({
    Key? key,
    required this.child,
    required this.value,
    this.backgroundColor = Colors.white,
    this.textColor = kAccentColor,
    this.right = -10,
    this.top = -12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(child: child),
        value > 0
            ? Positioned(
                right: right,
                top: top,
                // child: Chip(
                //   backgroundColor: color,
                //   // labelPadding: EdgeInsets.all(4),
                //   padding: EdgeInsets.zero,
                //   visualDensity: VisualDensity.compact,
                //   label: Text(value.toString(), style: AppTheme.numberStyle.copyWith(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                // ),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
                  child: Text(
                    value.toString(),
                    style: AppTheme.numberStyle.copyWith(fontSize: 10, color: textColor, fontWeight: FontWeight.w600),
                    textScaler: const TextScaler.linear(1),
                  ),
                ),
                // child: CircleAvatar(
                //   backgroundColor: color,
                //   child: Padding(
                //     padding: const EdgeInsets.all(0),
                //     child:
                //         Text(value.toString(), style: AppTheme.numberStyle.copyWith(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                //   ),
                // ),
              )
            : const SizedBox(),
      ],
    );
  }
}
