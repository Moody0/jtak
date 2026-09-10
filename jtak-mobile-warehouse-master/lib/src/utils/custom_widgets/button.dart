import 'package:flutter/material.dart';

class ButtonWidget extends StatelessWidget {
  final String text;
  final Function() onPressed;
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
        child: Text(text, style: textStyle),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          backgroundColor: color,
        ),
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
    this.elevation = 5,
    Key? key,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      child: child,
      onPressed: onTap,
      height: dimension,
      shape: const CircleBorder(),
      color: color,
      elevation: elevation,
      padding: padding,
      splashColor: color,
    );
  }
}
