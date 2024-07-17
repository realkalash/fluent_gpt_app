import 'dart:convert';
import 'dart:math';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/overlay/sidebar_overlay_ui.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:system_tray/system_tray.dart';
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
  print(count);
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
  static void init() {
    final customPromptsJson = AppCache.customPrompts.value;
    if (customPromptsJson != null && customPromptsJson.isNotEmpty) {
      final customPromptsList = jsonDecode(customPromptsJson) as List<dynamic>;
      final customPromptsListDecoded =
          customPromptsList.map((e) => CustomPrompt.fromJson(e)).toList();
      customPrompts.add(customPromptsListDecoded);
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
    String? command,
  }) async {
    if (overlayVisibility.value.isShowingOverlay ||
        AppCache.enableOverlay.value == false) {
      return;
    }
    overlayVisibility.add(OverlayStatus.enabled);
    await windowManager.setAlwaysOnTop(true);
    final compactOverlaySize = OverlayUI.defaultWindowSize();
    await windowManager.setSize(compactOverlaySize, animate: true);
    await windowManager.setResizable(false);
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
    await windowManager.setSize(compactOverlaySize, animate: true);
    // wait for the window to be resized
    await Future.delayed(const Duration(milliseconds: 100));
    await windowManager.setResizable(false);
    if (SidebarOverlayUI.previousCompactOffset != Offset.zero) {
      await windowManager.setPosition(
        SidebarOverlayUI.previousCompactOffset,
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
    overlayVisibility.add(OverlayStatus.disabled);
    await AppWindow().hide();
  }

  static Future<void> switchToMainWindow() async {
    windowManager.setAlwaysOnTop(AppCache.alwaysOnTop.value!);
    await windowManager.setResizable(true);
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
      print('Error repositioning window: $e');
    }
  }
}
