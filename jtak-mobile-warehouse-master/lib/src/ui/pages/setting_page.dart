import 'package:flutter/material.dart';
import 'package:app_jtak_warehouse/src/config/themes/colors.dart';
import 'package:app_jtak_warehouse/src/ui/pages/pages/app_page.dart';
import 'package:app_jtak_warehouse/src/utils/custom_widgets/widgets.dart';
import 'package:app_jtak_warehouse/src/utils/utilities/global_var.dart';
import 'package:provider/provider.dart';

import '../../core/controllers/app/app_state_manager.dart';
import '../../core/enums/theme_type.dart';
import '../../utils/custom_widgets/init_widget.dart';
import '../../../main_imports.dart';

class SettingPage extends StatelessWidget {
  static const String routeName = '/SettingPage';
  const SettingPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    AppStateManager appStateManager = Provider.of<AppStateManager>(context);
    Color iconColor = kAccentColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SettingPage'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('language'),
              trailing: Text(appStateManager.getOppositeLanguage()),
              onTap: () {
                try {
                  appStateManager.setAppLanguage(appStateManager.getOppositeLanguage());
                  InitWidget.restartApp(context);
                } catch (err) {
                  debugPrint(err.toString());
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Theme'),
              trailing: Text(appStateManager.appThemeType.value),
              onTap: () {
                try {
                  if (appStateManager.appThemeType == ThemeType.light) {
                    appStateManager.setAppTheme(ThemeType.dark);
                  } else {
                    appStateManager.setAppTheme(ThemeType.light);
                  }
                } catch (err) {
                  debugPrint(err.toString());
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.info, color: iconColor),
              title: Text(str.main.about),
              trailing: const ArrowWidget(),
              onTap: () => appPageNavigation(context, 'About', str.main.about),
            ),
          ],
        ),
      ),
    );
  }

  void appPageNavigation(BuildContext context, String pageType, String pageTitle) {
    context.navigatePage(AppPage(pageType: pageType, pageTitle: pageTitle));
  }
}
