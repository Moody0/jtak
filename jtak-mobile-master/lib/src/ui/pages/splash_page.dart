import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/app_global_initializer.dart';

import '../../../main_imports.dart';
import '../../config/constants/constants.dart';
import '../../utils/custom_widgets/messages.dart';
import '../../utils/utilities/global_var.dart';
import 'main_page.dart';

class SplashPage extends StatefulWidget {
  static const String routeName = '/SplashPage';
  const SplashPage({Key? key}) : super(key: key);
  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    super.initState();
    initAppState();
  }

  void initAppState() async {
    print("SplashPage: initAppState START");
    try {
      print("SplashPage: Calling appLoadMainData");
      await AppGlobalInitializer.appLoadMainData(context);
    } catch (err) {
      print("SplashPage: ERROR $err");
    } finally {
      if (mounted) {
        print("SplashPage: Navigating to MainPage");
        context.navigateToReset(MainPage.routeName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print("SplashPage BUILD");
    return Scaffold(
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: context.width * 0.25),
        alignment: Alignment.center,
        child: Image.asset(kLogo),
      ),
    );
  }

  @override
  void dispose() {
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);

    super.dispose();
  }
}
