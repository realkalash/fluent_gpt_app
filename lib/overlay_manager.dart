import 'package:chatgpt_windows_flutter_app/common/prefs/app_cache.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

BehaviorSubject<bool> isShowingOverlay = BehaviorSubject<bool>.seeded(false);

class OverlayManager {
  static var oldScreenWidth = 0.0;
  static var oldScreenHeight = 0.0;

  static Future<void> showOverlay(
    BuildContext rootContext, {
    double? positionX,
    double? positionY,
    String? command,
    required Size resolution,
  }) async {
    if (isShowingOverlay.value || AppCache.enableOverlay.value == false) {
      return;
    }
    isShowingOverlay.add(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setResizable(false);
    await windowManager.setSize(const Size(340, 64));
    // Invert positionY to start from the bottom
    if (positionY != null) {
      positionY = resolution.height - positionY;

      // Ensure the overlay does not go off-screen
      if (positionY < 0) {
        positionY = 0;
      }
    }
    if (positionX != null) {
      // Ensure the overlay does not go off-screen
      if (positionX < 0) {
        positionX = 0;
      }
    }
    await windowManager.setPosition(
      Offset(
        (positionX ?? 20) + 16,
        (positionY ?? 100) + 16,
      ),
    );

    oldScreenHeight = AppCache.windowHeight.value?.toDouble() ?? 700.0;
    oldScreenWidth = AppCache.windowWidth.value?.toDouble() ?? 500.0;
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
    final oldPositionX = AppCache.windowX.value;
    final oldPositionY = AppCache.windowY.value;
    await windowManager.setPosition(
      Offset(oldPositionX!.toDouble(), oldPositionY!.toDouble()),
      animate: true,
    );
    await Future.delayed(const Duration(milliseconds: 60));
    await windowManager.setSize(
      Size(oldScreenWidth, oldScreenHeight),
      animate: true,
    );
  }
}
