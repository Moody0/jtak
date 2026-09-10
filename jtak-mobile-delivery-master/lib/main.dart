import 'dart:developer';

import 'package:app_jtak_delivery/src/core/services/app_global_initializer.dart';
import 'package:app_jtak_delivery/src/core/services/authentication_service.dart';
import 'package:app_jtak_delivery/src/ui/pages/account/login_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../main_imports.dart';
import 'locale_delegate.dart';
import 'src/config/constants/constants.dart';
import 'src/config/routes/route_generator.dart';
import 'src/config/routes/routes.dart';
import 'src/core/controllers/app/root_provider.dart';
import 'src/core/controllers/app/app_state_manager.dart';
import 'src/core/enums/theme_type.dart';
import 'src/config/themes/theme.dart';
import 'src/ui/pages/splash_page.dart';
import 'src/utils/custom_widgets/init_widget.dart';
import 'src/utils/utilities/global_var.dart';

void main() async {
  await AppGlobalInitializer.mainInitializer();
  runApp(
    const RootProvider(
      child: InitWidget(
        child: AppRootWidget(),
      ),
    ),
  );
}

class AppRootWidget extends StatelessWidget {
  const AppRootWidget({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    log('**************************************** AppRootWidget.build');
    AppStateManager appStateManager = Provider.of<AppStateManager>(context);

    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      locale: Locale(appStateManager.appLanguage),
      localizationsDelegates: LocalDelegate.localizationsDelegates,
      supportedLocales: LocalDelegate.supportedLocales,
      localeResolutionCallback: LocalDelegate.localeResolutionCallback,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: appStateManager.appThemeType == ThemeType.dark ? ThemeMode.dark : ThemeMode.light,
      home: const MyApp(),
      // Initially display FirstPage
      initialRoute: '/',
      onGenerateRoute: RouteGenerator.generateRoute,
      routes: appRoutes,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  static const String routeName = '/';
  @override
  Widget build(BuildContext context) {
    str = context.str!;
    if (Provider.of<AuthenticationService>(context, listen: false).isLogin()) {
      return const SplashPage();
    }
    return const LoginPage();
    // return GlobalVar.appFirstLunch ? ChangeNotifierProvider(create: (context) => SetupWizardNotifier(), child: SetupWizardPage()) : SplashPage();
  }
}
