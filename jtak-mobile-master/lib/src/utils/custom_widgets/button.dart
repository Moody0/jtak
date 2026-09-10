import 'package:flutter/material.dart';
import '../../../main_imports.dart';

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
      margin: margin ?? EdgeInsets.symmetric(horizontal: context.width * 0.1, vertical: 4),
      child: ElevatedButton(
        child: Text(text, style: textStyle),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: padding,
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
    return SizedBox(
      width: dimension,
      height: dimension,
      child: FloatingActionButton(
        heroTag: DateTime.now().millisecondsSinceEpoch,
        elevation: elevation,
        backgroundColor: color,
        child: Padding(
          padding: padding,
          child: child,
        ),
        onPressed: onTap,
      ),
    );
  }
}
