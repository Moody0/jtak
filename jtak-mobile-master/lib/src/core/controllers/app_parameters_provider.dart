import 'package:flutter/material.dart' show BuildContext;
import 'package:jtek_app/src/core/controllers/app/base_provider.dart';
import 'package:jtek_app/src/core/services/main_address_service.dart';
import 'package:jtek_app/src/core/services/firebase_notification_services.dart';
import 'package:jtek_app/src/core/services/local_notification_service.dart';

class AppParametersProvider extends BaseProvider {
  late final MainAddressService mainAddressService;
  final FireBaseNotificationServices notificationServices = FireBaseNotificationServices();
  final LocalNotificationService localNotificationService = LocalNotificationService();

  AppParametersProvider() {
    mainAddressService = MainAddressService(onAddressChanged: notifyListeners);
  }

  Future loadMainParameters(BuildContext context) async {
    await mainAddressService.checkMainCorrdinate(context);
    notifyListeners();
  }

  Future initServices(BuildContext context) async {
    notificationServices.initialize(context);
    localNotificationService.context = context;
  }

  Future resetData() async {
    notificationServices.deleteInstance();
    // mainAddressService.reset();
  }
}
