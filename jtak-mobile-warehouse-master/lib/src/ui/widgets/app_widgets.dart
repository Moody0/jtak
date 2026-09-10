import 'package:flutter/material.dart';
import '../../config/constants/constants.dart';
import '../../config/themes/colors.dart';
import '../../utils/utilities/global_var.dart';
import '../../../main_imports.dart';

class AppBarWidget {
  static PreferredSizeWidget getAppBar({Widget? leading}) {
    return AppBar(
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Image.asset(kLogo2),
      ),
      centerTitle: true,
      leading: leading,
    );
  }
}

class NoDataAvailableWidget extends StatelessWidget {
  final String? msg;
  final Widget? image;
  const NoDataAvailableWidget({this.msg, this.image});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          image ?? Image.asset(kAssetsImageBase + ('no_data_available.png'), color: kAccentColor, height: 100),
          context.addHeight(16),
          Center(child: Text(msg ?? str.msg.noDataAvailable, style: context.textTheme.bodyText1!.copyWith(color: kAccentColor.withOpacity(0.7)))),
        ],
      ),
    );
  }
}
