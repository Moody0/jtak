import 'package:flutter/material.dart';

import '../../core/controllers/app/app_state_manager.dart';
import '../../core/services/locator.dart';

class ArrowWidget extends StatelessWidget {
  final Color color;
  final double size;
  const ArrowWidget({this.color = Colors.grey, this.size = 24});

  static IconData getArrowIconData() {
    return locator<AppStateManager>().appLanguageIsArabic ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Icon(ArrowWidget.getArrowIconData(), color: color, size: size);
  }
}
