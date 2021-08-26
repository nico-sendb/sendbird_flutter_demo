import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sendbird_flutter_demo/main.dart';
import 'package:sendbird_sdk/constant/enums.dart';

// Android: Show foreground notifications
// Docs: https://firebase.flutter.dev/docs/messaging/notifications#notification-channels
AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id - added inside of ./android/app/src/main/AndroidManifest.xml
  'High Importance Notifications', // title
  'This channel is used for important notifications.', // description
  importance: Importance.max,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage remoteMessage) async {
  debugPrint('Got a notification whilst in the background!');
  FirebasePush.showNotification(remoteMessage);
}

void _firebaseMessagingForegroundHandler(RemoteMessage remoteMessage) {
  debugPrint('Got a notification whilst in the foreground!');
  FirebasePush.showNotification(remoteMessage);
}

class FirebasePush {
  late Future<FirebaseMessaging> messaging;

  FirebasePush() {
    this.messaging = this.init();
  }

  Future<FirebaseMessaging> init() async {
    await Firebase.initializeApp();
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? firebaseToken = await messaging.getToken();

    if (firebaseToken != null) {
      debugPrint('firebaseToken: ${firebaseToken.toString()}');
      await sendbird.registerPushToken(
          type: PushTokenType.fcm, token: firebaseToken);
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // iOS: Display notifications while in the foreground
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true, // Required to display a heads up notification
      badge: true,
      sound: true,
    );

    // Listen for background incoming push notifications
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Listen for foreground incoming push notifications
    FirebaseMessaging.onMessage.listen(_firebaseMessagingForegroundHandler);

    return messaging;
  }

  static void showNotification(RemoteMessage remoteMessage) {
    // debugPrint('remote message data: ${remoteMessage.data}');
    // debugPrint('remote message data: ${remoteMessage.notification}');

    if (remoteMessage.notification != null) {
      flutterLocalNotificationsPlugin.show(
          remoteMessage.notification.hashCode,
          remoteMessage.notification?.title,
          remoteMessage.notification?.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channel.description,
              icon: "@drawable/ic_stat_name",
            ),
          ));
    } else {
      var sendbirdData = jsonDecode(remoteMessage.data["sendbird"]);
      flutterLocalNotificationsPlugin.show(
          sendbirdData["message_id"],
          'New message!',
          sendbirdData["message"],
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channel.description,
              icon: "@drawable/ic_stat_name",
            ),
          ));
    }
  }
}
