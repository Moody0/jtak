import 'package:app_jtak_warehouse/src/config/constants/constants.dart';
import 'package:app_jtak_warehouse/src/core/controllers/app_parameters_provider.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/ui/pages/order/orders_page.dart';
import 'package:app_jtak_warehouse/src/ui/sections/drawer.dart';
import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  static const String routeName = '/MainPage';
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  Widget homeBody = OrdersPage();
  String PageTitle = 'صفحة الطلبات';

  void drawerHandler(Widget page, String title) {
    setState(() {
      homeBody = page;
      PageTitle = title;
    });
  }

  @override
  void initState() {
    locator<AppParametersProvider>().initServices(context);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        if (PageTitle != 'صفحة الطلبات') {
          drawerHandler(OrdersPage(), 'صفحة الطلبات');
          return Future.value(false);
        }
        return Future.value(true);
      },
      child: Scaffold(
        appBar: _appBar(),
        body: SafeArea(child: homeBody),
        drawer: HomeDrawer(drawerHandler),
      ),
    );
  }

  AppBar _appBar() {
    return AppBar(
      titleSpacing: 0,
      title: Text(PageTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Image.asset(kLogo2),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
