// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'dart:io';

import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/features/imgur_integration.dart';
import 'package:fluent_gpt/features/push_to_talk_tool.dart';
import 'package:fluent_gpt/features/screenshot_tool.dart';
import 'package:fluent_gpt/features/souce_nao_image_finder.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/overlay/overlay_ui.dart';
import 'package:fluent_gpt/widgets/input_field.dart';
import 'package:flutter/foundation.dart';
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
  MenuItem(label: 'Show', onClick: (_) => showWindow()),
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
  showWindow();
}

/// You can use [TrayCommand] enum to send commands to the app.
///
/// Example: `onTrayButtonTapCommand('Hello World', TrayCommand.paste.name);`
Future<void> onTrayButtonTapCommand(String promptText,
    [String? command, Map<String, dynamic>? data]) async {
  /// generate a command with prompt uri
  const urlScheme = 'fluentgpt';
  final uri = Uri(scheme: urlScheme, path: '///', queryParameters: {
    'command': command ?? TrayCommand.custom.name,
    'text': promptText,
    if (data != null) ...data,
  });

  trayButtonStream.add(uri.toString());
  if (data?['status'] == 'silent') return;
  final visible = await windowManager.isVisible();
  if (!visible) {
    await showWindow();
  }
}

enum TrayCommand {
  paste,
  custom,
  push_to_talk_message,
  show_dialog,
  grammar,
  explain,
  to_rus,
  to_eng,
  improve_writing,
  summarize_markdown_short,
  answer_with_tags,
  create_new_chat,
  reset_chat,
  escape_cancel_select,
  paste_attachment_silent,
  paste_attachment_ai_lens,
  generate_image,
}

Future showWindow() async {
  log('Showing Window');
  await windowManager.show(inactive: false);
  if (Platform.isMacOS) {
    // await windowManager.focus();
  }
}

Future hideWindow() async {
  log('Hiding Window');
  await windowManager.hide();
}

/// Opens window/focus on the text field if opened, or hides the window if already opened and focused
HotKey openWindowHotkey = HotKey(
  key: LogicalKeyboardKey.digit1,
  modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
  scope: HotKeyScope.system,
);
HotKey openSearchOverlayHotkey = HotKey(
  key: LogicalKeyboardKey.space,
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
HotKey? pttScreenshotKey;
HotKey? pttKey;
Future<void> initShortcuts() async {
  await hotKeyManager.register(
    openWindowHotkey,
    keyDownHandler: (hotKey) async {
      final isAppVisible = await windowManager.isVisible();
      log('Open Window Hotkey: $isAppVisible');
      if (isAppVisible) {
        hideWindow();
      } else {
        await showWindow();
      }
    },
  );
  await hotKeyManager.register(
    openSearchOverlayHotkey,
    keyDownHandler: (hotKey) async {
      final isAppVisible = await windowManager.isVisible() &&
          overlayVisibility.value.isShowingSearchOverlay;
      if (isAppVisible) {
        await hideWindow();
      } else {
        await showWindow();
        OverlayManager.showSearchOverlay();
      }
    },
  );
  await hotKeyManager.register(
    createNewChat,
    keyDownHandler: (hotKey) async {
      onTrayButtonTapCommand('', TrayCommand.create_new_chat.name);
      await Future.delayed(const Duration(milliseconds: 200));
      promptTextFocusNode.requestFocus();
    },
  );
  await hotKeyManager.register(
    resetChat,
    keyDownHandler: (hotKey) async {
      onTrayButtonTapCommand('', TrayCommand.reset_chat.name);
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
  final takeScreenshotKey = AppCache.takeScreenshotKey.value;
  final pttScreenshotKeyCached = AppCache.pttScreenshotKey.value;
  final pttKeyCached = AppCache.pttKey.value;

  if (openWindowKey != null) {
    await hotKeyManager.unregister(openWindowHotkey);
    openWindowHotkey = HotKey.fromJson(jsonDecode(openWindowKey));
    await hotKeyManager.register(
      openWindowHotkey,
      keyDownHandler: (hotKey) async {
        if (_isHotKeyRegistering) return;
        _isHotKeyRegistering = true;

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
        // if (isAppVisible && !isInputFieldFocused) {
        //   /// if currently showing overlay, open the chatUI
        //   if (overlayVisibility.value.isShowingSidebarOverlay) {
        //     SidebarOverlayUI.isChatVisible.add(true);
        //   } else if (overlayVisibility.value.isShowingOverlay) {
        //     OverlayUI.isChatVisible.add(true);
        //   }

        //   await windowManager.show();
        //   // to focus the window we show it twice on macos
        //   if (Platform.isMacOS) {
        //     await windowManager.show();
        //   }
        //   promptTextFocusNode.requestFocus();
        //   _isHotKeyRegistering = false;
        //   return;
        // }
        if (!isAppVisible) {
          await showWindow();
          _isHotKeyRegistering = false;
          return;
        }
      },
    );
  }
  if (takeScreenshotKey != null) {
    takeScreenshot = HotKey.fromJson(jsonDecode(takeScreenshotKey));
    await hotKeyManager.register(
      takeScreenshot!,
      keyDownHandler: (hotKey) async {
        if (ScreenshotTool.isCapturingState) {
          return;
        }
        final base64Result = (Platform.isMacOS || Platform.isWindows)
            ? await ScreenshotTool.takeScreenshotReturnBase64Native()
            : await ScreenshotTool.takeScreenshotReturnBase64();
        if (base64Result != null && base64Result.isNotEmpty) {
          onTrayButtonTapCommand(base64Result, 'paste_attachment_ai_lens');
          if (Platform.isMacOS) {
            await Future.delayed(const Duration(milliseconds: 200));
            showWindow();
          }
        }
      },
    );
  }
  if (pttScreenshotKeyCached != null) {
    pttScreenshotKey = HotKey.fromJson(jsonDecode(pttScreenshotKeyCached));
    await hotKeyManager.register(
      pttScreenshotKey!,
      keyDownHandler: (hotKey) async {
        log('PTT Screenshot Key Down');
        if (Platform.isWindows) {
          // take a screenshot
          final screenshot = (Platform.isMacOS || Platform.isWindows)
              ? await ScreenshotTool.takeScreenshotReturnBase64Native()
              : await ScreenshotTool.takeScreenshotReturnBase64();
          if (screenshot != null && screenshot.isNotEmpty) {
            onTrayButtonTapCommand(screenshot, 'paste_attachment_silent');
          }
          // on windows we don't have keyUpHandler, so we need to stop the PTT on key down
          if (PushToTalkTool.isRecording) {
            final text = await PushToTalkTool.stop();
            if (text != null && text.isNotEmpty) {
              onTrayButtonTapCommand(text, 'push_to_talk_message');
            }
            return;
          }
        }
        PushToTalkTool.start();
      },
      keyUpHandler: (hotKey) async {
        log('PTT Screenshot Key Up');
        final text = await PushToTalkTool.stop();
        if (text != null && text.isNotEmpty) {
          final screenshot = (Platform.isMacOS || Platform.isWindows)
              ? await ScreenshotTool.takeScreenshotReturnBase64Native()
              : await ScreenshotTool.takeScreenshotReturnBase64();
          if (screenshot != null && screenshot.isNotEmpty) {
            onTrayButtonTapCommand(screenshot, 'paste_attachment_silent');
            await Future.delayed(const Duration(milliseconds: 50));
          }
          onTrayButtonTapCommand(text, 'push_to_talk_message');
        }
      },
    );
    if (pttKeyCached != null) {
      pttKey = HotKey.fromJson(jsonDecode(pttKeyCached));
      await hotKeyManager.register(
        pttKey!,
        keyDownHandler: (hotKey) async {
          log('PTT Key Down');
          if (Platform.isWindows) {
            // on windows we don't have keyUpHandler, so we need to stop the PTT on key down
            if (PushToTalkTool.isRecording) {
              final text = await PushToTalkTool.stop();
              if (text != null && text.isNotEmpty) {
                onTrayButtonTapCommand(text, 'push_to_talk_message');
              }
              return;
            }
          }
          PushToTalkTool.start();
        },
        keyUpHandler: (hotKey) async {
          log('PTT Key Up');
          final text = await PushToTalkTool.stop();
          if (text != null && text.isNotEmpty) {
            onTrayButtonTapCommand(text, 'push_to_talk_message');
          }
        },
      );
    }
  }
}

class AppTrayListener extends TrayListener {
  /// Emitted when the mouse clicks the tray icon.
  @override
  void onTrayIconMouseDown() {
    if (kDebugMode) {
      print('onTrayIconMouseUp');
    }
    if (Platform.isWindows) {
      windowManager.isVisible().then((isVisible) async {
        if (isVisible) {
          windowManager.hide();
        } else {
          await showWindow();
        }
      });
    }
  }

  /// Emitted when the mouse is released from clicking the tray icon.
  @override
  void onTrayIconMouseUp() {
    if (kDebugMode) {
      print('onTrayIconMouseUp');
    }
    windowManager.isVisible().then((isVisible) async {
      if (isVisible) {
        windowManager.hide();
        OverlayUI.isChatVisible.add(false);
        overlayVisibility.add(OverlayStatus.disabled);
      } else {
        final cursorPos = await NativeChannelUtils.getMousePosition();
        await showWindow();
        if (cursorPos != null) {
          // dy is 961 instead of 38. We need to calc based on the height of the window
          final screen = await NativeChannelUtils.getScreenSize();
          final height = screen?['height'] ?? 720;
          final modifCursorPos = Offset(cursorPos.dx, cursorPos.dy - height);
          windowManager.setPosition(modifCursorPos, animate: false);
          OverlayUI.isChatVisible.add(true);
          overlayVisibility.add(OverlayStatus.enabled);

          /// because focus node is linked to both widgets we need to unfocus from the old one
          promptTextFocusNode.unfocus();
          await Future.delayed(const Duration(milliseconds: 100));
          promptTextFocusNode.requestFocus();
        }
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
