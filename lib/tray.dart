import 'dart:io';

import 'package:chatgpt_windows_flutter_app/pages/home_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initSystemTray() async {
  String path =
      Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';

  final AppWindow appWindow = AppWindow();
  final SystemTray systemTray = SystemTray();

  // We first init the systray menu
  await systemTray.initSystemTray(
    title: "system tray",
    iconPath: path,
    isTemplate: true,
    toolTip: "FluentGPT",
  );

  // create context menu
  final Menu menu = Menu();
  await menu.buildFrom([
    MenuItemLabel(label: 'Show', onClicked: (menuItem) => appWindow.show()),
    MenuItemLabel(label: 'Hide', onClicked: (menuItem) => appWindow.hide()),
    MenuItemLabel(label: 'Exit', onClicked: (menuItem) => appWindow.close()),
  ]);

  // set context menu
  await systemTray.setContextMenu(menu);

  // handle system tray event
  systemTray.registerSystemTrayEventHandler((eventName) {
    debugPrint("eventName: $eventName");
    if (eventName == kSystemTrayEventClick) {
      Platform.isWindows ? appWindow.show() : systemTray.popUpContextMenu();
    } else if (eventName == kSystemTrayEventRightClick) {
      Platform.isWindows ? systemTray.popUpContextMenu() : appWindow.show();
    }
  });
  await initShortcuts(appWindow);
}

HotKey openWindowHotkey = HotKey(
  KeyCode.digit1,
  modifiers: [KeyModifier.control, KeyModifier.shift],
  // Set hotkey scope (default is HotKeyScope.system)
  scope: HotKeyScope.system, // Set as inapp-wide hotkey.
);
Future<void> initShortcuts(AppWindow appWindow) async {
  await hotKeyManager.register(
    openWindowHotkey,
    keyDownHandler: (hotKey) async {
      print('onKeyDown+${hotKey.toJson()}');
      final isAppVisible = await windowManager.isVisible();

      if (isAppVisible) {
        appWindow.hide();
      } else {
        appWindow.show();
        promptTextFocusNode.requestFocus();
      }
    },
  );
}
