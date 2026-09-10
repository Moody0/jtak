import 'package:app_jtak_delivery/src/core/controllers/app/base_provider.dart';
import 'package:app_jtak_delivery/src/core/services/firebase_notification_services.dart';
import 'package:app_jtak_delivery/src/core/services/local_notification_service.dart';
import 'package:flutter/material.dart' show BuildContext;

class AppParametersProvider extends BaseProvider {
  FireBaseNotificationServices notificationServices = FireBaseNotificationServices();
  LocalNotificationService localNotificationService = LocalNotificationService();

  Future initServices(BuildContext context) async {
    notificationServices.initialize(context);
    localNotificationService.context = context;
  }

  Future resetData() async {
    notificationServices.deleteInstance();
  }
}
