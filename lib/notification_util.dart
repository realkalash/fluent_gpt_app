import 'dart:developer';
import 'dart:io';

import 'package:fluent_gpt/features/notification_service.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:window_manager/window_manager.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // handle action
  log('Notification tapped: ${notificationResponse.payload}');
  showWindow();
}

@pragma('vm:entry-point')
Future<void> onDidReceiveLocalNotification(
    int id, String? title, String? body, String? payload) async {
  // handle notification
}

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();
const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
  // onDidReceiveLocalNotification: onDidReceiveLocalNotification,
  requestAlertPermission: false,
  requestSoundPermission: false,
  requestBadgePermission: false,
  defaultPresentBanner: true,
  notificationCategories: [
    DarwinNotificationCategory(
      'default',
      actions: <DarwinNotificationAction>[
        // DarwinNotificationAction.plain('id_1', 'Action 1'),
      ],
    ),
  ],
);
const LinuxInitializationSettings initializationSettingsLinux =
    LinuxInitializationSettings(defaultActionName: 'Open notification');

InitializationSettings get notificationInitSettingsPlatform {
  if (Platform.isWindows) {
    throw UnsupportedError('Windows is not supported. Use WindowsPlugin');
  }
  return InitializationSettings(
    iOS: initializationSettingsDarwin,
    macOS: initializationSettingsDarwin,
    linux: initializationSettingsLinux,
  );
}

Future initializeNotifications(String? appId) async {
  if (Platform.isWindows) {
    await NotificationService.init(appId);
    return;
  }

  const InitializationSettings initializationSettings = InitializationSettings(
    iOS: initializationSettingsDarwin,
    macOS: initializationSettingsDarwin,
    linux: initializationSettingsLinux,
  );
  await notificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) async {
      log('Notification response received: ${notificationResponse.payload}');
      if (await windowManager.isFocused() == false) {
        showWindow();
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );
}
