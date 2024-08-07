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
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:rxdart/rxdart.dart';

/// Can handle direct commands as [paste, grammar, explain, to_rus, to_eng] (Value from clipboard will be used as text)
/// or onProtocol url link as myApp://command?text=Hello%20World
final trayButtonStream = BehaviorSubject<String?>();
AppTrayListener appTrayListener = AppTrayListener();

Future<void> initSystemTray() async {
  String? path;
  if (Platform.isWindows) {
    path = 'assets/app_icon.ico';
  } else if (Platform.isMacOS) {
    path = 'assets/transparent_app_icon_32x32.png';
  } else if (Platform.isLinux) {
    path = 'assets/app_icon.png';
  }
  if (path == null) return;

  // final AppWindow appWindow = AppWindow();
  // final SystemTray systemTray = SystemTray();

  // We first init the systray menu
  await trayManager.setIcon(
    path,
    isTemplate: true,
  );

  // create context menu
  final Menu menu = Menu(items: [
    MenuItem(label: 'Show', onClick: (menuItem) => windowManager.show()),
    MenuItem(label: 'Hide', onClick: (menuItem) => windowManager.hide()),
    MenuItem(label: 'Exit', onClick: (menuItem) => windowManager.close()),
  ]);

  // set context menu
  await trayManager.setContextMenu(menu);

  // handle system tray event
  trayManager.removeListener(appTrayListener);
  trayManager.addListener(appTrayListener);
  await initShortcuts();
}

@Deprecated('Use onTrayButtonTapCommand instead')
onTrayButtonTap(String item) {
  trayButtonStream.add(item);
  windowManager.show();
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
    windowManager.show();
  }
}

/// If the window is visible or not
BehaviorSubject<bool> windowVisibilityStream =
    BehaviorSubject<bool>.seeded(true);

showWindow() {
  windowManager.show();
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
Future<void> initShortcuts() async {
  await hotKeyManager.register(
    openWindowHotkey,
    keyDownHandler: (hotKey) async {
      final isAppVisible = await windowManager.isVisible();
      isAppVisible ? windowManager.hide() : windowManager.show();
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
          await windowManager.hide();
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
          await windowManager.show();
          // to focus the window we show it twice
          windowManager.show();
          return;
        }
        if (!isAppVisible) {
          windowManager.show();
          return;
        }
      },
    );
  }
}

class AppTrayListener extends TrayListener {
  /// Emitted when the mouse clicks the tray icon.
  @override
  void onTrayIconMouseDown() {}

  /// Emitted when the mouse is released from clicking the tray icon.
  @override
  void onTrayIconMouseUp() {
    // if visible -> hide, else show
    windowManager.isVisible().then((isVisible) {
      if (isVisible) {
        windowManager.hide();
      } else {
        windowManager.show();
        windowManager.focus();
      }
    });
  }

  @override
  void onTrayIconRightMouseDown() {}

  @override
  void onTrayIconRightMouseUp() {
    trayManager.popUpContextMenu();
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    log('onTrayMenuItemClick: ${menuItem.label}');
    if (menuItem.onClick != null) {
      menuItem.onClick!(menuItem);
      return;
    }
    if (menuItem.label == 'Show') {
      windowManager.show();
    } else if (menuItem.label == 'Hide') {
      windowManager.hide();
    } else if (menuItem.label == 'Exit') {
      windowManager.close();
    }
  }
}
