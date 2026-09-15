import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jtek_app/src/utils/custom_widgets/custom_scroll_behavior.dart';
import 'src/core/controllers/app/root_provider.dart';
import 'src/core/controllers/app/app_state_manager.dart';
import 'src/core/services/app_global_initializer.dart';
import 'src/utils/utilities/global_var.dart';
import 'package:provider/provider.dart';
import 'locale_delegate.dart';
import 'src/config/constants/constants.dart';
import 'src/config/routes/route_generator.dart';
import 'src/config/routes/routes.dart';
import 'src/ui/pages/splash_page.dart';
import 'src/utils/custom_widgets/init_widget.dart';
import '../../../main_imports.dart';

class JtakHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = JtakHttpOverrides();
  print("STARTING MAIN");
  try {
    await AppGlobalInitializer.mainInitializer();
    print("FINISHED AppGlobalInitializer");
  } catch (e, stack) {
    print("ERROR in mainInitializer: $e\n$stack");
  }
  
  print("CALLING runApp");
  runApp(
    const RootProvider(
      child: InitWidget(
        child: AppRootWidget(),
      ),
    ),
  );
}

class AppRootWidget extends StatefulWidget {
  const AppRootWidget({Key? key}) : super(key: key);

  @override
  State<AppRootWidget> createState() => _AppRootWidgetState();
}

class _AppRootWidgetState extends State<AppRootWidget> {
  late AppStateManager appStateManager;

  @override
  Widget build(BuildContext context) {
    print("INSIDE AppRootWidget BUILD");
    log('**************************************** AppRootWidget.build');
    final appStateManager = Provider.of<AppStateManager>(context);

    return MaterialApp(
      title: kAppName,
      localizationsDelegates: const [
        LocalDelegate(),
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],

      supportedLocales: LocalDelegate.supportedLocales,
      // Returns a locale which will be used by the app
      localeResolutionCallback: (locale, supportedLocales) {
        if (appStateManager.appLanguage.isNotEmpty) {
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == appStateManager.appLanguage) return supportedLocale;
          }
        }
        // If the locale of the device is not supported, use the first one
        // from the list (English, in this case).
        return supportedLocales.first;
      },
      scrollBehavior: CustomScrollBehavior(),
      theme: appStateManager.getAppThemeData(),
      debugShowCheckedModeBanner: false,
      home: const MyApp(),
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
    print("INSIDE MyApp BUILD");
    if (context.str == null) {
      print("context.str is null, returning Scaffold");
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    print("context.str is NOT null, returning SplashPage");
    str = context.str!;
    return const SplashPage();
  }
}
