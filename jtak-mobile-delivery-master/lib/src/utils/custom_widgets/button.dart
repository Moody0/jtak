import 'package:flutter/material.dart';
import '../../config/themes/colors.dart';

class ButtonWidget extends StatelessWidget {
  final String text;
  final Function()? onPressed;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? width;
  final Color? color;
  final TextStyle? textStyle;
  final AlignmentGeometry? alignment;

  const ButtonWidget({
    required this.text,
    required this.onPressed,
    this.padding,
    this.margin,
    this.width,
    this.color,
    this.textStyle,
    this.alignment,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      alignment: alignment,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: color ?? kPrimaryOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(text, style: textStyle ?? const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}

class CircularButton extends StatelessWidget {
  final Widget child;
  final Function() onTap;
  final double dimension;
  final Color color;
  final EdgeInsets padding;
  final double elevation;

  const CircularButton({
    required this.child,
    required this.onTap,
    this.dimension = 35,
    this.color = Colors.white,
    this.padding = EdgeInsets.zero,
    this.elevation = 0,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: dimension,
      width: dimension,
      child: RawMaterialButton(
        onPressed: onTap,
        elevation: elevation,
        fillColor: color,
        padding: padding,
        shape: const CircleBorder(),
        child: child,
      ),
    );
  }
}
