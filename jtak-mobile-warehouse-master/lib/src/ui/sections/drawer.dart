import 'package:app_jtak_warehouse/src/config/constants/constants.dart';
import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/core/services/authentication_service.dart';
import 'package:app_jtak_warehouse/src/ui/pages/account/profile_page.dart';
import 'package:app_jtak_warehouse/src/ui/pages/catalog/products_page.dart';
import 'package:app_jtak_warehouse/src/ui/pages/order/orders_page.dart';
import 'package:app_jtak_warehouse/src/ui/pages/pages/app_page.dart';
import 'package:app_jtak_warehouse/src/ui/pages/transaction/transaction_page.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../main_imports.dart';

class HomeDrawer extends StatefulWidget {
  final Function drawerHandler;

  HomeDrawer(this.drawerHandler);

  @override
  _HomeDrawerState createState() => _HomeDrawerState();
}

class _HomeDrawerState extends State<HomeDrawer> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            _headerSection(),
            _accountSection(),
            _divider(height: 4),
            context.addHeight(16),
            _singleItem(
                text: 'صفحة الطلبات',
                onTap: () {
                  Navigator.pop(context);
                  widget.drawerHandler(OrdersPage(), 'صفحة الطلبات');
                }),
            _singleItem(
                text: 'منتجاتي',
                onTap: () {
                  Navigator.pop(context);
                  widget.drawerHandler(SearchPage(), 'منتجاتي');
                }),
            _singleItem(
                text: 'اخر الحركات',
                onTap: () {
                  Navigator.pop(context);
                  widget.drawerHandler(TransactionPage(), 'اخر التحركات');
                }),
            _singleItem(text: str.app.privecyAndUsage, onTap: () => appPageNavigation(context, 'TermsAndConditions', str.app.privecyAndUsage)),
            _singleItem(text: str.main.about, onTap: () => appPageNavigation(context, 'About', str.main.about)),
          ],
        ),
      ),
    );
  }

  Widget _singleItem({required String text, void Function()? onTap}) {
    return ListTile(
      leading: const SizedBox(),
      title: Text(text, style: context.textTheme.headline4?.copyWith(fontSize: 14)),
      onTap: () {
        if (onTap != null) onTap();
      },
      visualDensity: VisualDensity.compact,
    );
  }

  void appPageNavigation(BuildContext context, String pageType, String pageTitle) {
    Navigator.pop(context);
    context.navigatePage(AppPage(pageType: pageType, pageTitle: pageTitle));
  }

  Widget _divider({double height = 1}) {
    return Container(width: double.infinity, height: height, color: Colors.grey.shade100);
  }

  Widget _headerSection() {
    return Container(
      height: 150,
      width: double.infinity,
      child: Image.asset(kLogo),
    );
  }

  Widget _accountSection() {
    return Consumer<AuthenticationService>(
      builder: (context, value, child) {
        return ListTile(
          leading: Icon(Icons.person, color: kPrimaryColor),
          title: Text(
            value.user?.fullName ?? '',
            style: context.textTheme.headline4,
          ),
          onTap: () {
            Navigator.pop(context);
            context.navigateName(ProfilePage.routeName);
          },
        );
      },
    );
  }
}
