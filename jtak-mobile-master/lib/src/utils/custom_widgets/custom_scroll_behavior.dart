import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Global Custom Scroll Behavior (Zero Stretch / Bounce / Glow Effect)
///
/// Completely disables overscroll stretching, bouncing, and glowing indicators
/// across all scrollable lists, grids, and views throughout the entire app.
/// ---------------------------------------------------------------------------
class CustomScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
