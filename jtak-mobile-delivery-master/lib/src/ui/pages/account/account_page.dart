import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:app_jtak_delivery/src/utils/custom_widgets/messages.dart';

import '../../../../main_imports.dart';
import '../../../config/themes/colors.dart';
import '../../../core/services/authentication_service.dart';
import '../../../core/services/locator.dart';
import '../../../utils/custom_widgets/widgets.dart';
import '../../../utils/utilities/global_var.dart';
import 'login_page.dart';
import 'profile_page.dart';

class AccountPage extends StatelessWidget {
  static const String routeName = '/AccountPage';
  const AccountPage();
  @override
  Widget build(BuildContext context) {
    log('^^^^^^^^^^^^^^^^^^^^^^^^^^^^ AccountPage.build');
    Color iconColor = kAccentColor;
    return Scaffold(
      appBar: AppBar(
        title: Text(str.main.thePersonalAccount),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            ListTile(
              leading: Icon(Icons.person, color: iconColor),
              title: Text(str.main.profile),
              trailing: const ArrowWidget(),
              onTap: () {
                if (locator<AuthenticationService>().isLogin()) {
                  context.navigateName(ProfilePage.routeName);
                } else {
                  context.navigateName(LoginPage.routeName);
                }
              },
            ),
            const Divider(),
            _logoutWidget(iconColor, context),
            const Divider(),
          ],
        ),
      ),
    );
  }

  ListTile _logoutWidget(Color iconColor, BuildContext context) {
    bool isLogin = locator<AuthenticationService>().isLogin();
    String title = isLogin ? str.formAndAction.logout : str.formAndAction.logIn;
    return ListTile(
      leading: Icon(Icons.reviews, color: iconColor),
      title: Text(title),
      trailing: const ArrowWidget(),
      onTap: () {
        if (isLogin) {
          showDialog(
            context: context,
            builder: (context) => CustomConfirmationDialog(
              title: str.formAndAction.logout,
              message: str.msg.logoutConfirm,
              yesBTNCallBack: () async {
                await locator<AuthenticationService>().logOut();
                context.navigateToReset(LoginPage.routeName);
              },
            ),
          );
        } else {
          context.navigateName(LoginPage.routeName);
        }
      },
    );
  }
}
