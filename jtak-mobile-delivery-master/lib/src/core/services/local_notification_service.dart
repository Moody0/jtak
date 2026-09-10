import 'package:app_jtak_delivery/src/core/models/notifications_payload_model.dart';
import 'package:app_jtak_delivery/src/core/services/notification_routes_service.dart';
import 'package:app_jtak_delivery/src/utils/utilities/global_var.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// dependencies:
//   flutter_local_notifications:

class LocalNotificationService {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  late AndroidInitializationSettings androidInitializationSettings;
  late DarwinInitializationSettings iosInitializationSettings;
  late InitializationSettings initializationSettings;

  BuildContext? context;
  LocalNotificationService() {
    initializing();
  }

  void initializing() async {
    androidInitializationSettings = const AndroidInitializationSettings('notification_icon');
    iosInitializationSettings = const DarwinInitializationSettings();
    initializationSettings = InitializationSettings(android: androidInitializationSettings, iOS: iosInitializationSettings);
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onSelectNotification(response.payload);
      },
    );
    _requestIOSPermissions();
  }

  void _requestIOSPermissions() {
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void showNotifications(NotificationPayloadModel item) async {
    await _notification(item);
  }

  Future<void> _notification(NotificationPayloadModel item) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'GlobalNotification',
      'اشعارات التطبيق',
      channelDescription: 'اشعارات التطبيق',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    DarwinNotificationDetails iosNotificationDetails = const DarwinNotificationDetails();
    NotificationDetails notificationDetails = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosNotificationDetails,
    );

    int notificationId = DateTime.now().millisecond;
    await flutterLocalNotificationsPlugin.show(
      id: notificationId,
      title: item.title ?? '',
      body: item.text ?? '',
      notificationDetails: notificationDetails,
      payload: item.toJson(),
    );
  }

  void onSelectNotification(String? payload) {
    _openNotification(payload);
  }

  void onDidReceiveLocalNotification(int id, String? title, String? body, String? payload) async {
    _openNotification(payload);
  }

  void _openNotification(String? payload) {
    if (payload != null) {
      GlobalVar.log(' 🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔 onDidReceiveLocalNotification payload: $payload');
      NotificationPayloadModel notificationPayload = NotificationPayloadModel.fromJson(payload);
      GlobalVar.log(' 🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔   payload after decode : $notificationPayload');
      if (context == null) throw Exception('context not added to notification service');
      NotificationRoutesService notificationRoutesService = NotificationRoutesService(context!);
      notificationRoutesService.parseNotificationUrl(notificationPayload);
    }
  }
}
