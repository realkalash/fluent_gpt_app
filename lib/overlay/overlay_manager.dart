import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/prompts_templates.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/overlay/sidebar_overlay_ui.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:rxdart/rxdart.dart';
import 'package:window_manager/window_manager.dart';

import '../common/custom_prompt.dart';
import 'overlay_ui.dart';

BehaviorSubject<OverlayStatus> overlayVisibility =
    BehaviorSubject<OverlayStatus>.seeded(OverlayStatus());

BehaviorSubject<List<CustomPrompt>> customPrompts =
    BehaviorSubject.seeded([...basePromptsTemplate]);
BehaviorSubject<List<CustomPrompt>> archivedPrompts =
    BehaviorSubject.seeded([...baseArchivedPromptsTemplate]);

int calcAllPromptsForChild(CustomPrompt prompt) {
  int count = 1;
  for (var child in prompt.children) {
    count += calcAllPromptsForChild(child);
  }
  return count;
}

int calcAllPromptsLenght() {
  final archivedList = archivedPrompts.value.toList();
  final customList = customPrompts.value.toList();
  int count = 0;
  for (var prompt in customList) {
    count += calcAllPromptsForChild(prompt);
  }
  for (var prompt in archivedList) {
    count += calcAllPromptsForChild(prompt);
  }
  return count;
}

class OverlayStatus {
  final bool isShowingOverlay;
  final bool isShowingSidebarOverlay;
  OverlayStatus({
    this.isShowingOverlay = false,
    this.isShowingSidebarOverlay = false,
  });

  bool get isEnabled => isShowingOverlay || isShowingSidebarOverlay;

  static OverlayStatus enabled = OverlayStatus(isShowingOverlay: true);
  static OverlayStatus disabled = OverlayStatus(isShowingOverlay: false);
  static OverlayStatus sidebarEnabled =
      OverlayStatus(isShowingSidebarOverlay: true);
  static OverlayStatus sidebarDisabled =
      OverlayStatus(isShowingSidebarOverlay: false);

  //equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OverlayStatus &&
        other.isShowingOverlay == isShowingOverlay &&
        other.isShowingSidebarOverlay == isShowingSidebarOverlay;
  }

  @override
  int get hashCode =>
      isShowingOverlay.hashCode ^ isShowingSidebarOverlay.hashCode;
}

class OverlayManager {
  static Future<void> init() async {
    final customPromptsJson = await AppCache.customPrompts.value();
    if (customPromptsJson.isNotEmpty) {
      final customPromptsList = jsonDecode(customPromptsJson) as List<dynamic>;
      final customPromptsListDecoded =
          customPromptsList.map((e) => CustomPrompt.fromJson(e)).toList();
      customPrompts.add(customPromptsListDecoded);
      bindHotkeys(customPromptsListDecoded);
    }
    final archivedPromptsJson = AppCache.archivedPrompts.value;
    if (archivedPromptsJson != null && archivedPromptsJson.isNotEmpty) {
      final archivedPromptsList = jsonDecode(archivedPromptsJson) as List;
      final archivedPromptsListDecoded =
          archivedPromptsList.map((e) => CustomPrompt.fromJson(e)).toList();
      archivedPrompts.add(archivedPromptsListDecoded);
    }
    customPrompts.listen((newData) {
      AppCache.customPrompts.set(
        jsonEncode(newData.map((e) => e.toJson()).toList()),
      );
    });
  }

  static Future<void> showOverlay(
    BuildContext rootContext, {
    double? positionX,
    double? positionY,
  }) async {
    if (overlayVisibility.value.isShowingOverlay ||
        AppCache.enableOverlay.value == false) {
      return;
    }
    overlayVisibility.add(OverlayStatus.enabled);
    await windowManager.setAlwaysOnTop(true);

    final compactOverlaySize = OverlayUI.defaultWindowSize();
    await windowManager.setMinimumSize(compactOverlaySize);
    await windowManager.setSize(compactOverlaySize, animate: true);
    await windowManager.setResizable(false);
    // Ensure the overlay does not go off-screen
    if (positionX != null && positionY != null) {
      // we need to invert Y because the overlay is from the bottom to top
      final resolutionStr = AppCache.resolution.value ?? '500x700';
      final resHeight = double.tryParse(resolutionStr.split('x')[1]) ?? 700;
      positionY = resHeight - positionY;
      if (positionY < 0) {
        positionY = 0;
      }
      // Ensure the overlay does not go off-screen
      if (positionX < 0) {
        positionX = 0;
      }
      // because if chatUI is opening it can try to use previous position, we need to wait until the animation is done
      await Future.delayed(const Duration(milliseconds: 500));
      await windowManager.setPosition(
        Offset((positionX), (positionY)),
        animate: false,
      );
    }
  }

  static Future<void> showSidebarOverlay(
    BuildContext rootContext, {
    double? positionX,
    double? positionY,
    String? command,
  }) async {
    if (overlayVisibility.value.isShowingSidebarOverlay ||
        AppCache.enableOverlay.value == false) {
      return;
    }
    overlayVisibility.add(OverlayStatus.sidebarEnabled);
    await windowManager.setAlwaysOnTop(true);
    final compactOverlaySize = SidebarOverlayUI.defaultWindowSize();
    await windowManager.setMinimumSize(compactOverlaySize);
    await windowManager.setSize(compactOverlaySize, animate: true);
    // wait for the window to be resized
    await Future.delayed(const Duration(milliseconds: 100));
    await windowManager.setResizable(false);
    if (AppCache.previousCompactOffset.value != Offset.zero) {
      await windowManager.setPosition(
        AppCache.previousCompactOffset.value!,
        animate: false,
      );
    } else {
      // Ensure the overlay does not go off-screen
      if (positionX != null && positionY != null) {
        if (positionY < 0) {
          positionY = 0;
        }
        // Ensure the overlay does not go off-screen
        if (positionX < 0) {
          positionX = 0;
        }
        await windowManager.setPosition(
          Offset((positionX) + 16, (positionY) + 16),
          animate: true,
        );
      }
    }
  }

  static Future<void> hideOverlay() async {
    windowManager.setAlwaysOnTop(AppCache.alwaysOnTop.value!);
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(defaultMinimumWindowSize);
    overlayVisibility.add(OverlayStatus.disabled);
    await windowManager.hide();
  }

  static Future<void> switchToMainWindow() async {
    windowManager.setAlwaysOnTop(AppCache.alwaysOnTop.value!);
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(defaultMinimumWindowSize);
    overlayVisibility.add(OverlayStatus.disabled);
    await windowManager.setPosition(
      Offset(
        AppCache.windowX.value!.toDouble(),
        AppCache.windowY.value!.toDouble(),
      ),
      animate: true,
    );
    // delay due to macos bug. We can't do it simulteniously
    await Future.delayed(const Duration(milliseconds: 200));
    await windowManager.setSize(
      Size(AppCache.windowWidth.value?.toDouble() ?? 600.0,
          AppCache.windowHeight.value?.toDouble() ?? 700.0),
      animate: true,
    );
    await Future.delayed(const Duration(milliseconds: 200));
    await OverlayManager.checkAndRepositionOverOffsetWindow();
  }

  static Future checkAndRepositionOverOffsetWindow() async {
    try {
      final currentPosition = await windowManager.getPosition();
      final windowSize = await windowManager.getSize();
      final resolutionString = AppCache.resolution.value ?? '500x700';
      final resList = resolutionString.split('x');
      if (resList.length != 2) {
        throw const FormatException('Invalid resolution format');
      }
      final resolutionSize =
          Size(double.parse(resList[0]), double.parse(resList[1]));

      double newX = currentPosition.dx;
      double newY = currentPosition.dy;

      // Adjust X if out of bounds
      if (newX + windowSize.width > resolutionSize.width) {
        // 70 is the additional padding for the window by width
        newX = resolutionSize.width - windowSize.width + 70;
      }
      newX = max(0, newX); // Ensure newX is not negative

      // Adjust Y if out of bounds
      if (newY + windowSize.height > resolutionSize.height) {
        // 24 is the additional padding for the window by height
        newY = resolutionSize.height - windowSize.height + 24;
      }
      newY = max(0, newY); // Ensure newY is not negative

      // Reposition only if necessary
      if (newX != currentPosition.dx || newY != currentPosition.dy) {
        await windowManager.setPosition(Offset(newX, newY), animate: true);
      }
    } catch (e) {
      // Handle or log the error
      logError('Error repositioning window: $e');
    }
  }

  static void bindHotkeys(List<CustomPrompt> customPromptsList) {
    for (var prompt in customPromptsList) {
      if (prompt.hotkey != null) {
        _bindHotkey(prompt, prompt.hotkey!);
      }
    }
  }

  /// On linux hotkey registration is so fast it could trigger
  /// the hotkey 3 times in a row, so we need to lock it
  static bool _isHotKeyRegistering = false;
  static Future<void> _bindHotkey(CustomPrompt prompt, HotKey key) async {
    // each prompt can have multiple children
    for (var child in prompt.children) {
      if (child.hotkey != null) {
        await _bindHotkey(child, child.hotkey!);
      }
    }

    await hotKeyManager.register(
      key,
      keyDownHandler: (hotKey) async {
        if (_isHotKeyRegistering) return;
        _isHotKeyRegistering = true;
        final previousClipboard =
            (await Clipboard.getData(Clipboard.kTextPlain))?.text;

        String? selectedText; //await NativeChannelUtils.getSelectedText();
        // if (prompt.autoCopySelectedText) {
        await simulateCtrlCKeyPress();
        await Future.delayed(const Duration(milliseconds: 50));
        // }
        selectedText = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
        final isAppVisible = await windowManager.isVisible();

        /// show app window
        if (!isAppVisible) {
          final Offset? mouseCoord =
              await NativeChannelUtils.getMousePosition();
          // windows can't resize windows at all
          if (!Platform.isLinux) {
            /// show mini overlay
            if (!overlayVisibility.value.isEnabled) {
              await showOverlay(
                navigatorKey.currentContext!,
                positionX: mouseCoord?.dx,
                positionY: mouseCoord?.dy,
              );
            }
          }
        }
        await windowManager.show();
        if (!Platform.isLinux) {
          /// if already open show chat UI inside the overlay
          if (overlayVisibility.value.isShowingSidebarOverlay) {
            SidebarOverlayUI.isChatVisible.add(true);
          } else if (overlayVisibility.value.isShowingOverlay) {
            OverlayUI.isChatVisible.add(true);
          }
        }

        if (previousClipboard != null) {
          Clipboard.setData(ClipboardData(text: previousClipboard));
        }

        await onTrayButtonTapCommand(prompt.getPromptText(selectedText));
        _isHotKeyRegistering = false;
      },
    );
  }
}
