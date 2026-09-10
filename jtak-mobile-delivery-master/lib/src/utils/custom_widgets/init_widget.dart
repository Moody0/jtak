import 'package:flutter/material.dart';

class InitWidget extends StatefulWidget {
  const InitWidget({required this.child, Key? key}) : super(key: key);

  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_InitWidgetState>()!.restartApp();
  }

  @override
  _InitWidgetState createState() => _InitWidgetState();
}

class _InitWidgetState extends State<InitWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}
