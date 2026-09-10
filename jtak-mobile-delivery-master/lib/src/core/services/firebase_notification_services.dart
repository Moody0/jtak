import 'package:app_jtak_delivery/src/core/controllers/app/app_state_manager.dart';
import 'package:app_jtak_delivery/src/core/controllers/app_parameters_provider.dart';
import 'package:app_jtak_delivery/src/core/models/notifications_payload_model.dart';
import 'package:app_jtak_delivery/src/core/services/authentication_service.dart';
import 'package:app_jtak_delivery/src/core/services/locator.dart';
import 'package:app_jtak_delivery/src/core/services/notification_routes_service.dart';
import 'package:app_jtak_delivery/src/utils/utilities/global_var.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class FireBaseNotificationServices {
  late FirebaseMessaging _firebaseMessaging;
  BuildContext? context;

  static Future basicInitialize() async {
    await Firebase.initializeApp();
    // FirebaseMessaging.onBackgroundMessage(_messageHandler);
  }

  void initialize(BuildContext context) {
    this.context = context;
    _firebaseMessaging = FirebaseMessaging.instance;
    _getToken();
    requestPermission();
    _registerListener();
  }

  void _registerListener() async {
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      GlobalVar.log("🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔 firebase Messaging InitialMessage");
      if (message != null) {
        GlobalVar.log(message.notification?.title ?? '');
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // app is in foregrounde
      GlobalVar.log("🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔 Firebase Messaging recieved");
      locator<AppParametersProvider>().localNotificationService.showNotifications(getPayloadModel(message.data));
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // app is in background or killed and user tap on default notification
      GlobalVar.log(' 🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔 notification clicked!');
      if (context == null) throw Exception('context not added to notification service');
      NotificationRoutesService notificationRoutesService = NotificationRoutesService(context!);
      notificationRoutesService.parseNotificationUrl(getPayloadModel(message.data));
    });
  }

  NotificationPayloadModel getPayloadModel(Map<String, dynamic> data) {
    return NotificationPayloadModel(
      id: int.tryParse(data['Id']),
      title: data['Title'],
      text: data['Text'],
      imageUrl: data['ImageUrl'],
      url: data['Url'],
      topic: data['Topic'],
      entity: data['Entity'],
      entityData: data['EntityData'],
      createdDate: data['CreatedDate'],
    );
  }

  Future requestPermission() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  void _getToken() async {
    String? token = await _firebaseMessaging.getToken();
    assert(token != null);
    {
      GlobalVar.log('******************************************* firebase token : $token');
      AuthenticationService authService = locator<AuthenticationService>();
      if (authService.user != null && GlobalVar.checkString(authService.user!.userTopicId)) {
        subscribeToTopic(authService.user!.userTopicId);
      }
    }
  }

  void deleteInstance() => _firebaseMessaging.deleteToken();

  void subscribeToTopic(topic) {
    String newTopic = topic + '_' + locator<AppStateManager>().appLanguage;
    _firebaseMessaging.subscribeToTopic(newTopic).then((onValue) {
      GlobalVar.log('subscribed To Topic : $newTopic');
    }).catchError((err) {
      GlobalVar.log('subscribed To Topic error : ${err.toString()}');
    });
  }

  void unsubscribeFromTopic(topic) async {
    _firebaseMessaging.unsubscribeFromTopic(topic).then((onValue) {
      GlobalVar.log('unsubscribed To Topic : $topic');
    });
  }
}

// Future<void> _messageHandler(RemoteMessage message) async {
  // to handle firebase notification message when the app in background
//   GlobalVar.log('🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔 background firebase messageHandler title ${message.notification!.title}');
//   GlobalVar.log('🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔 background firebase messageHandler body ${message.notification!.body}');
// }
