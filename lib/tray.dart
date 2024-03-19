import 'dart:io';

import 'package:chatgpt_windows_flutter_app/pages/home_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:rxdart/rxdart.dart';

/// paste, grammar, explain, to_rus, to_eng
final trayButtonStream = BehaviorSubject<String?>();

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
  systemTray.registerSystemTrayEventHandler((eventName) async {
    debugPrint("eventName: $eventName");
    if (eventName == kSystemTrayEventClick) {
      if (Platform.isWindows) {
        appWindow.show();
      } else {
        systemTray.popUpContextMenu();
      }
    } else if (eventName == kSystemTrayEventRightClick) {
      final clipBoard = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipBoard?.text?.trim().isNotEmpty == true) {
        final first20CharIfPresent = clipBoard!.text!.length > 20
            ? clipBoard.text!.substring(0, 20)
            : clipBoard.text;
        menu.buildFrom([
          MenuItemLabel(
              label: 'Paste: "${first20CharIfPresent?.trim()}..."',
              onClicked: (menuItem) => onTrayButtonTap('paste')),
          MenuItemLabel(
              label: 'Grammar',
              onClicked: (menuItem) => onTrayButtonTap('grammar')),
          MenuItemLabel(
              label: 'Explain',
              onClicked: (menuItem) => onTrayButtonTap('explain')),
          MenuItemLabel(
              label: 'Translate to Russian',
              onClicked: (menuItem) => onTrayButtonTap('to_rus')),
          MenuItemLabel(
              label: 'Translate to English',
              onClicked: (menuItem) => onTrayButtonTap('to_eng')),
          MenuItemLabel(
              label: 'Answer with Tags',
              onClicked: (menuItem) => onTrayButtonTap('answer_with_tags')),
          MenuSeparator(),
          MenuItemLabel(
              label: 'Show', onClicked: (menuItem) => appWindow.show()),
          MenuItemLabel(
              label: 'Hide', onClicked: (menuItem) => appWindow.hide()),
          MenuItemLabel(
              label: 'Exit', onClicked: (menuItem) => appWindow.close()),
        ]);
        await systemTray.setContextMenu(menu);
      }
      if (Platform.isWindows) {
        systemTray.popUpContextMenu();
      } else {
        appWindow.show();
      }
    }
  });
  await initShortcuts(appWindow);
}

onTrayButtonTap(String item) {
  trayButtonStream.add(item);
  AppWindow().show();
}

HotKey openWindowHotkey = HotKey(
  key: LogicalKeyboardKey.digit1,
  modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
  scope: HotKeyScope.system,
);
HotKey createNewChat = HotKey(
  key: LogicalKeyboardKey.keyT,
  modifiers: [HotKeyModifier.control],
  scope: HotKeyScope.inapp,
);
HotKey resetChat = HotKey(
  key: LogicalKeyboardKey.keyR,
  modifiers: [HotKeyModifier.control],
  scope: HotKeyScope.inapp,
);
Future<void> initShortcuts(AppWindow appWindow) async {
  await hotKeyManager.register(
    openWindowHotkey,
    keyDownHandler: (hotKey) async {
      // print('onKeyDown+${hotKey.toJson()}');
      final isAppVisible = await windowManager.isVisible();

      if (isAppVisible) {
        appWindow.hide();
      } else {
        appWindow.show();
        promptTextFocusNode.requestFocus();
      }
    },
  );
  await hotKeyManager.register(
    createNewChat,
    keyDownHandler: (hotKey) async {
      onTrayButtonTap('create_new_chat');
      await Future.delayed(const Duration(milliseconds: 200));
      promptTextFocusNode.requestFocus();
    },
  );
  await hotKeyManager.register(
    resetChat,
    keyDownHandler: (hotKey) async {
      onTrayButtonTap('reset_chat');
      await Future.delayed(const Duration(milliseconds: 200));
      promptTextFocusNode.requestFocus();
    },
  );
}
