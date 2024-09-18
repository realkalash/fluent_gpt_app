import 'dart:convert';
import 'dart:io';

import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/features/imgur_integration.dart';
import 'package:fluent_gpt/features/screenshot_tool.dart';
import 'package:fluent_gpt/features/souce_nao_image_finder.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/overlay/overlay_ui.dart';
import 'package:fluent_gpt/overlay/sidebar_overlay_ui.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:rxdart/rxdart.dart';

/// Can handle direct commands as [paste, grammar, explain, to_rus, to_eng] (Value from clipboard will be used as text)
/// or onProtocol url link as myApp://command?text=Hello%20World
final trayButtonStream = BehaviorSubject<String?>();
AppTrayListener appTrayListener = AppTrayListener();
final List<MenuItem> trayMenuFooterItems = [
  MenuItem(label: 'Show', onClick: (_) => windowManager.show()),
  MenuItem(label: 'Hide', onClick: (_) => windowManager.hide()),
  MenuItem(
      label: 'Exit',
      onClick: (_) =>
          Platform.isMacOS ? windowManager.destroy() : windowManager.close()),
];

final List<MenuItem> trayMenuItems = [];

Future<void> initSystemTray() async {
  String? path;
  if (Platform.isWindows) {
    path = 'assets/app_icon.ico';
  } else if (Platform.isMacOS) {
    path = 'assets/transparent_app_icon_32x32.png';
  } else if (Platform.isLinux) {
    path = 'assets/app_icon512.png';
  }
  if (path == null) return;

  // final AppWindow appWindow = AppWindow();
  // final SystemTray systemTray = SystemTray();

  // We first init the systray menu
  await trayManager.setIcon(
    path,
    isTemplate: true,
  );

  await initTrayMenuItems();

  // handle system tray event
  trayManager.removeListener(appTrayListener);
  trayManager.addListener(appTrayListener);
  await initShortcuts();
}

Future<void> initTrayMenuItems() async {
  trayMenuItems.clear();
  trayMenuItems.addAll([
    MenuItem.submenu(
      label: 'Tools',
      submenu: Menu(items: [
        MenuItem(
          label: 'Search by Image SauceNao (Clipboard)',
          toolTip:
              'The image will be uploaded to Imgur and searched on SauceNao',
          icon: 'assets/saucenao_favicon.png',
          onClick: (menuItem) async {
            if (ImgurIntegration.isClientIdValid() == false) {
              onTrayButtonTapCommand(
                "You don't have Imgur integration enabled. Please, go to settings and set up ImgurAPI",
                'show_dialog',
              );
              return;
            }
            final clipboardBytesImage = await Pasteboard.image;
            if (clipboardBytesImage != null) {
              SauceNaoImageFinder.uploadToImgurAndFindImageBytes(
                clipboardBytesImage,
              );
            } else {
              onTrayButtonTapCommand(
                'No image found in the clipboard',
                'show_dialog',
              );
            }
          },
        ),
      ]),
    ),
    MenuItem.separator(),
    ...trayMenuFooterItems,
  ]);
  // create context menu
  final Menu menu = Menu(items: trayMenuItems);

  // set context menu
  await trayManager.setContextMenu(menu);
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
HotKey? takeScreenshot;
Future<void> initShortcuts() async {
  await hotKeyManager.register(
    openWindowHotkey,
    keyDownHandler: (hotKey) async {
      final isAppVisible = await windowManager.isVisible();
      log('Open Window Hotkey: $isAppVisible');
      if (isAppVisible) {
        log('Hiding Window');
        windowManager.hide();
      } else {
        log('Showing Window');
        windowManager.show();
      }
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

/// On linux hotkey registration is so fast it could trigger
/// the hotkey 3 times in a row, so we need to lock it
bool _isHotKeyRegistering = false;
Future<void> initCachedHotKeys() async {
  final openWindowKey = AppCache.openWindowKey.value;
  if (openWindowKey != null) {
    await hotKeyManager.unregister(openWindowHotkey);
    openWindowHotkey = HotKey.fromJson(jsonDecode(openWindowKey));
    await hotKeyManager.register(
      openWindowHotkey,
      keyDownHandler: (hotKey) async {
        if (_isHotKeyRegistering) return;
        _isHotKeyRegistering = true;

        /// Opens window/focus on the text field if opened, or hides the window if already opened and focused
        final isAppVisible =
            await windowManager.isVisible() && await windowManager.isVisible();
        final isInputFieldFocused = promptTextFocusNode.hasFocus;
        if (isAppVisible && isInputFieldFocused) {
          promptTextFocusNode.unfocus();
          await windowManager.hide();
          _isHotKeyRegistering = false;
          return;
        }
        if (Platform.isLinux) {
          if (isAppVisible && !isInputFieldFocused) {
            await windowManager.focus();
            promptTextFocusNode.requestFocus();
            _isHotKeyRegistering = false;
            return;
          }
        }
        if (isAppVisible && !isInputFieldFocused) {
          /// if currently showing overlay, open the chatUI
          if (overlayVisibility.value.isShowingSidebarOverlay) {
            SidebarOverlayUI.isChatVisible.add(true);
          } else if (overlayVisibility.value.isShowingOverlay) {
            OverlayUI.isChatVisible.add(true);
          }

          await windowManager.show();
          // to focus the window we show it twice on macos
          if (Platform.isMacOS) {
            await windowManager.show();
          }
          promptTextFocusNode.requestFocus();
          _isHotKeyRegistering = false;
          return;
        }
        if (!isAppVisible) {
          windowManager.show();
          _isHotKeyRegistering = false;
          return;
        }
      },
    );
  }
  final takeScreenshotKey = AppCache.takeScreenshotKey.value;
  if (takeScreenshotKey != null) {
    takeScreenshot = HotKey.fromJson(jsonDecode(takeScreenshotKey));
    await hotKeyManager.register(
      takeScreenshot!,
      keyDownHandler: (hotKey) async {
        if (ScreenshotTool.isCapturingState) {
          return;
        }
        final base64Result = await ScreenshotTool.takeScreenshotReturnBase64();
        if (base64Result != null && base64Result.isNotEmpty) {
          onTrayButtonTapCommand(base64Result, 'paste_attachment_ai_lens');
        }
      },
    );
  }
}

class AppTrayListener extends TrayListener {
  /// Emitted when the mouse clicks the tray icon.
  @override
  void onTrayIconMouseDown() {
    if (Platform.isWindows) {
      windowManager.isVisible().then((isVisible) {
        if (isVisible) {
          windowManager.hide();
        } else {
          windowManager.show();
          windowManager.focus();
        }
      });
    }
  }

  /// Emitted when the mouse is released from clicking the tray icon.
  @override
  void onTrayIconMouseUp() {
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
  void onTrayIconRightMouseDown() {
    if (Platform.isWindows) {
      trayManager.popUpContextMenu();
    }
  }

  @override
  void onTrayIconRightMouseUp() {
    trayManager.popUpContextMenu();
  }

  // @override
  // Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
  //   log('onTrayMenuItemClick: ${menuItem.label}');
  //   if (menuItem.onClick != null) {
  //     menuItem.onClick!(menuItem);
  //     return;
  //   }
  //   if (menuItem.label == 'Show') {
  //     windowManager.show();
  //   } else if (menuItem.label == 'Hide') {
  //     windowManager.hide();
  //   } else if (menuItem.label == 'Exit') {
  //     windowManager.close();
  //   }
  // }
}
