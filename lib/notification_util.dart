import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // handle action
}

@pragma('vm:entry-point')
Future<void> onDidReceiveLocalNotification(
    int id, String? title, String? body, String? payload) async {
  // handle notification
}

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();
Future initializeNotifications() async {
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    requestAlertPermission: false,
    requestSoundPermission: false,
    requestBadgePermission: false,
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
  const InitializationSettings initializationSettings = InitializationSettings(
    iOS: initializationSettingsDarwin,
    macOS: initializationSettingsDarwin,
    linux: initializationSettingsLinux,
  );
  await notificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) async {
      // ...
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );
}
