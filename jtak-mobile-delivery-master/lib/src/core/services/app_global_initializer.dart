import 'package:flutter/material.dart';
import 'package:app_jtak_delivery/src/core/controllers/initial_data_provider.dart';
import 'package:app_jtak_delivery/src/core/services/authentication_service.dart';
import 'package:app_jtak_delivery/src/core/services/firebase_notification_services.dart';
import 'package:app_jtak_delivery/src/core/services/locator.dart';
import 'package:provider/provider.dart';
import '../controllers/app/app_state_manager.dart';

class AppGlobalInitializer {
  static Future mainInitializer() async {
    // WidgetsFlutterBinding.ensureInitialized: Ensure that plugin services are initialized
    WidgetsFlutterBinding.ensureInitialized();
    await FireBaseNotificationServices.basicInitialize();
    setupLocator();
    await locator<AppStateManager>().initializAppState();
    await locator<AuthenticationService>().getAuthorizationData();
  }

  static Future appLoadMainData(BuildContext context) async {
    try {
      await Future.wait([
        Provider.of<InitialDataProvider>(context, listen: false).getInitData(),
      ]);
    } catch (err) {
      rethrow;
    }
  }
}
