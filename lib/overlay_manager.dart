import 'dart:convert';
import 'package:chatgpt_windows_flutter_app/common/prefs/app_cache.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'common/custom_prompt.dart';
import 'overlay_ui.dart';

BehaviorSubject<bool> isShowingOverlay = BehaviorSubject<bool>.seeded(false);
BehaviorSubject<List<CustomPrompt>> customPrompts =
    BehaviorSubject.seeded([...basePromptsTemplate]);
BehaviorSubject<List<CustomPrompt>> archivedPrompts =
    BehaviorSubject.seeded([...baseArchivedPromptsTemplate]);

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
    if (isShowingOverlay.value || AppCache.enableOverlay.value == false) {
      return;
    }
    isShowingOverlay.add(true);
    await windowManager.setAlwaysOnTop(true);
    final compactOverlaySize = OverlayUI.defaultWindowSize();
    await windowManager.setSize(compactOverlaySize, animate: true);
    await windowManager.setResizable(false);
    // final resolutionString = AppCache.resolution.value ?? '500x700';
    // final screenHeight = double.parse(resolutionString.split('x').last);
    // final screenWidth = double.parse(resolutionString.split('x').first);
    // final resolution = Size(screenWidth, screenHeight);

    // Invert positionY to start from the bottom
    // if (positionY != null) {
    //   positionY = resolution.height - positionY - compactOverlaySize.height;
    // }

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

  static Future<void> hideOverlay() async {
    windowManager.setAlwaysOnTop(AppCache.alwaysOnTop.value!);
    await windowManager.setResizable(true);
    isShowingOverlay.add(false);
    await AppWindow().hide();
  }

  static Future<void> switchToMainWindow() async {
    windowManager.setAlwaysOnTop(AppCache.alwaysOnTop.value!);
    await windowManager.setResizable(true);
    isShowingOverlay.add(false);
    await windowManager.setPosition(
      Offset(
        AppCache.windowX.value!.toDouble(),
        AppCache.windowY.value!.toDouble(),
      ),
      animate: true,
    );
    // delay due to macos bug. We can't do it simulteniously
    await Future.delayed(const Duration(milliseconds: 60));
    await windowManager.setSize(
      Size(AppCache.windowWidth.value?.toDouble() ?? 600.0,
          AppCache.windowHeight.value?.toDouble() ?? 700.0),
      animate: true,
    );
  }
}
