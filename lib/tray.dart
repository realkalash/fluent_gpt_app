import 'dart:convert';
import 'dart:io';

import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/overlay/overlay_ui.dart';
import 'package:fluent_gpt/overlay/sidebar_overlay_ui.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:rxdart/rxdart.dart';

import 'common/window_listener.dart';

/// Can handle direct commands as [paste, grammar, explain, to_rus, to_eng] (Value from clipboard will be used as text)
/// or onProtocol url link as myApp://command?text=Hello%20World
final trayButtonStream = BehaviorSubject<String?>();

Future<void> initSystemTray() async {
  if (Platform.isLinux) return;
  String path = Platform.isWindows
      ? 'assets/app_icon.ico'
      : 'assets/transparent_app_icon_32x32.png';

  final AppWindow appWindow = AppWindow();
  final SystemTray systemTray = SystemTray();

  // We first init the systray menu
  await systemTray.initSystemTray(
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
      AppWindowListener.windowVisibilityStream.value == false
          ? appWindow.show()
          : appWindow.hide();
    } else if (eventName == kSystemTrayEventRightClick) {
      final clipBoard = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipBoard?.text?.trim().isNotEmpty == true) {
        final first20CharIfPresent = clipBoard!.text!.length > 20
            ? clipBoard.text!.substring(0, 20)
            : clipBoard.text;
        menu.buildFrom([
          MenuItemLabel(
              label: 'Paste: "${first20CharIfPresent?.trim()}..."',
              onClicked: (menuItem) async => onTrayButtonTapCommand(
                  '${(await Pasteboard.text)}', 'paste')),
          MenuItemLabel(
              label: 'Grammar',
              onClicked: (menuItem) async => onTrayButtonTapCommand(
                  '${(await Pasteboard.text)}', 'grammar')),
          MenuItemLabel(
              label: 'Explain',
              onClicked: (menuItem) async => onTrayButtonTapCommand(
                  '${(await Pasteboard.text)}', 'explain')),
          MenuItemLabel(
              label: 'Translate to Russian',
              onClicked: (menuItem) async => onTrayButtonTapCommand(
                  '${(await Pasteboard.text)}', 'to_rus')),
          MenuItemLabel(
              label: 'Translate to English',
              onClicked: (menuItem) async => onTrayButtonTapCommand(
                  '${(await Pasteboard.text)}', 'to_eng')),
          MenuItemLabel(
              label: 'Answer with Tags',
              onClicked: (menuItem) async => onTrayButtonTapCommand(
                  '${(await Pasteboard.text)}', 'answer_with_tags')),
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

@Deprecated('Use onTrayButtonTapCommand instead')
onTrayButtonTap(String item) {
  trayButtonStream.add(item);
  AppWindow().show();
}

Future<void> onTrayButtonTapCommand(String promptText,
    [String? command]) async {
  /// generate a command with prompt uri
  const urlScheme = 'fluentgpt';
  final uri = Uri(scheme: urlScheme, path: '///', queryParameters: {
    'command': command ?? 'custom',
    'text': promptText,
  });

  trayButtonStream.add(uri.toString());
  final visible = await windowManager.isVisible();
  if (!visible) {
    AppWindow().show();
  }
}

/// If the window is visible or not
BehaviorSubject<bool> windowVisibilityStream =
    BehaviorSubject<bool>.seeded(true);

showWindow() {
  AppWindow().show();
}

/// Opens window/focus on the text field if opened, or hides the window if already opened and focused
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
HotKey showOverlayForText = HotKey(
  key: LogicalKeyboardKey.keyY,
  modifiers: [HotKeyModifier.control],
  scope: HotKeyScope.system,
);
Future<void> initShortcuts(AppWindow appWindow) async {
  await hotKeyManager.register(
    openWindowHotkey,
    keyDownHandler: (hotKey) async {
      final isAppVisible = await windowManager.isVisible();
      isAppVisible ? appWindow.hide() : appWindow.show();
    },
  );
  await hotKeyManager.register(
    createNewChat,
    keyDownHandler: (hotKey) async {
      onTrayButtonTapCommand('', 'create_new_chat');
      await Future.delayed(const Duration(milliseconds: 200));
      promptTextFocusNode.requestFocus();
    },
  );
  await hotKeyManager.register(
    resetChat,
    keyDownHandler: (hotKey) async {
      onTrayButtonTapCommand('', 'reset_chat');
      await Future.delayed(const Duration(milliseconds: 200));
      promptTextFocusNode.requestFocus();
    },
  );
  await hotKeyManager.register(
    showOverlayForText,
    keyDownHandler: (hotKey) async {
      // final result = await NativeChannelUtils.getSelectedText();
      // log('Selected Text: $result');
      final Offset? mouseCoord = await NativeChannelUtils.getMousePosition();
      log('Mouse Position: $mouseCoord');

      /// show mini overlay
      await OverlayManager.showOverlay(
        navigatorKey.currentContext!,
        positionX: mouseCoord?.dx,
        positionY: mouseCoord?.dy ?? 0 + 1,
      );
    },
  );
  initCachedHotKeys();
}

Future<void> initCachedHotKeys() async {
  final openWindowKey = AppCache.openWindowKey.value;
  if (openWindowKey != null) {
    await hotKeyManager.unregister(openWindowHotkey);
    openWindowHotkey = HotKey.fromJson(jsonDecode(openWindowKey));
    await hotKeyManager.register(
      openWindowHotkey,
      keyDownHandler: (hotKey) async {
        /// Opens window/focus on the text field if opened, or hides the window if already opened and focused
        final isAppVisible = await windowManager.isVisible();
        final isInputFieldFocused = promptTextFocusNode.hasFocus;
        if (isAppVisible && isInputFieldFocused) {
          promptTextFocusNode.unfocus();
          await AppWindow().hide();
          return;
        }
        if (isAppVisible && !isInputFieldFocused) {
          /// if currently showing overlay, open the chatUI
          if (overlayVisibility.value.isShowingSidebarOverlay) {
            SidebarOverlayUI.isChatVisible.add(true);
          } else if (overlayVisibility.value.isShowingOverlay) {
            OverlayUI.isChatVisible.add(true);
          }

          promptTextFocusNode.requestFocus();
          await AppWindow().show();
          // to focus the window we show it twice
          AppWindow().show();
          return;
        }
        if (!isAppVisible) {
          AppWindow().show();
          return;
        }
      },
    );
  }
}
