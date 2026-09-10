import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jtek_app/src/core/controllers/app_parameters_provider.dart';
import 'package:jtek_app/src/core/controllers/initial_data_provider.dart';
import 'package:jtek_app/src/core/controllers/user/address_provider.dart';
import 'package:jtek_app/src/core/services/locator.dart';
import 'package:jtek_app/src/utils/utilities/global_var.dart';
import '../../config/themes/colors.dart';
import '../../core/controllers/app/home_navigation_provider.dart';
import '../sections/bottom_navigation.dart';
import 'package:provider/provider.dart';
import '../../../main_imports.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  static const String routeName = '/MainPage';
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late HomeNavigationProvider homeNavigationProvider;

  @override
  void initState() {
    log('^^^^^^^^^^^^^^^^^^^^^^^^^^^^ MainPage : initState ');

    initialize();
    checkingList();
    _checkAppLifecycleState();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    homeNavigationProvider = Provider.of<HomeNavigationProvider>(context);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: context.appTheme.primaryColor,
      statusBarIconBrightness: Brightness.light,
    ));
    return WillPopScope(
      onWillPop: homeNavigationProvider.onWillPop,
      child: Scaffold(
        backgroundColor: kPageBackground,
        body: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: KeyedSubtree(
                key: ValueKey(homeNavigationProvider.currentIndex),
                child: homeNavigationProvider.getMainWidget(),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: BottomNavigation(
                onChange: (index) => homeNavigationProvider.changePage(index),
              ),
            )
          ],
        ),
      ),
    );
  }

  void initialize() {
    HomeNavigationProvider homeNavigationProvider = Provider.of<HomeNavigationProvider>(context, listen: false);
    homeNavigationProvider.currentIndex = 0;
    locator<AppParametersProvider>().initServices(context);
  }

  void checkingList() {
    Future.microtask(() {
      AddressProvider addressProvider = Provider.of<AddressProvider>(context, listen: false);
      if (GlobalVar.checkString(addressProvider.globalMessage)) {
        context.showSnakBar(addressProvider.globalMessage);
        addressProvider.globalMessage = null;
      }
    });
  }

  void _checkAppLifecycleState() {
    SystemChannels.lifecycle.setMessageHandler((msg) {
      debugPrint('^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^SystemChannels> $msg');
      if (msg == AppLifecycleState.resumed.toString()) {
        Provider.of<InitialDataProvider>(context, listen: false).getInitData(context);
      }
      return Future.value(msg);
    });
  }
}
