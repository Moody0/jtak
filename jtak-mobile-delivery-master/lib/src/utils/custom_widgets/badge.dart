import 'package:flutter/material.dart';

import '../../config/themes/app_theme.dart';
import '../../config/themes/colors.dart';

class Badge extends StatelessWidget {
  final Widget child;
  final int value;
  final Color color;
  final double right;
  final double top;

  const Badge({
    Key? key,
    required this.child,
    required this.value,
    this.color = kAccentColor,
    this.right = 3,
    this.top = 6,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        child,
        value > 0
            ? Positioned(
                right: right,
                top: top,
                child: CircleAvatar(
                  backgroundColor: color,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child:
                        Text(value.toString(), style: AppTheme.numberStyle.copyWith(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                  minRadius: 9,
                ),
              )
            : const SizedBox(),
      ],
    );
  }
}
