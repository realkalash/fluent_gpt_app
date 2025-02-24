import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:fluent_gpt/notification_util.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:windows_notification/notification_message.dart';
import 'package:windows_notification/windows_notification.dart';

class NotificationService {
  static late WindowsNotification _winNotifyPlugin;
  /* 

// Create an instance of Windows Notification with your application name
// application id must be null in packaged mode


// create new NotificationMessage instance with id, title, body, and images
NotificationMessage message = NotificationMessage.fromPluginTemplate(
      "test1",
      "TEXT",
      "TEXT",
      largeImage: file_path,
      image: file_path
);


// show notification    
_winNotifyPlugin.showNotificationPluginTemplate(message);
   */

  static Future<void> init(String? appId) async {
    _winNotifyPlugin = WindowsNotification(applicationId: appId);
    await _winNotifyPlugin.initNotificationCallBack(
      (details) {
        log("Win Notification callback: ${details.eventType}");
        // not working on the plugin level
        if (details.eventType != EventType.onActivate) {
          return;
        }
        notificationTapBackground(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: jsonEncode(details.userInput),
          ),
        );
      },
    );

    log("Notification service activated with app id: $appId");
  }

  static Future<void> showNotification(
    String title,
    String body, {
    /// should be string number
    String? id,
    Map<String, dynamic> payload = const {},
    String? thumbnailFilePath,
    String? imageFilePath,
  }) async {
    String _id = id ?? generate16ID();
    if (Platform.isWindows) {
      NotificationMessage message = NotificationMessage.fromPluginTemplate(
        _id,
        title,
        body,
        largeImage: imageFilePath,
        image: thumbnailFilePath,
        payload: payload,
      );

      _winNotifyPlugin.showNotificationPluginTemplate(message);
      return;
    }
    if (Platform.isMacOS || Platform.isIOS) {
      final permission =
          await MacOSFlutterLocalNotificationsPlugin().checkPermissions();
      if (permission?.isEnabled == false) {
        await MacOSFlutterLocalNotificationsPlugin().requestPermissions(
          alert: true,
          badge: true,
          provisional: true,
        );
      }
      final stringPayload = jsonEncode(payload);
      await notificationsPlugin.show(
        int.tryParse(_id) ?? 999,
        title,
        body,
        null,
        payload: stringPayload,
      );
      return;
    }
    if (Platform.isLinux) {
      final stringPayload = jsonEncode(payload);
      await notificationsPlugin.show(
        int.tryParse(_id) ?? 999,
        title,
        body,
        null,
        payload: stringPayload,
      );
      return;
    }
  }
}
