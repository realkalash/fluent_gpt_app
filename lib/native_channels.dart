// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:io';

import 'package:fluent_gpt/log.dart';
import 'package:flutter/services.dart';
import 'package:keypress_simulator/keypress_simulator.dart';

const overlayChannel = MethodChannel('com.realk.fluent_gpt');

class NativeChannelUtils {
  static void testChannel() async {
    if (Platform.isLinux) return;
    try {
      final result = await overlayChannel.invokeMethod('testResultFromSwift');
      print('Result from Swift: $result');
    } on PlatformException catch (e) {
      print("Failed to get result from Swift: '${e.message}'.");
    }
  }

  static Future<String?> getSelectedText() async {
    // Skip selected text retrieval for Linux and macOS since accessibility features are disabled
    if (Platform.isLinux || Platform.isMacOS) return null;
    try {
      final String? selectedText = await overlayChannel.invokeMethod('getSelectedText');
      print('[Dart] Selected text from clipboard: ${selectedText ?? "No text selected"}');
      if (selectedText == null || selectedText.isEmpty) {
        return null;
      }
      return selectedText;
    } on PlatformException catch (e) {
      print("Failed to get selected text: '${e.message}'.");
      return null;
    }
  }

  static void showOverlay() async {
    // Skip overlay functionality for Linux and macOS since accessibility features are disabled
    if (Platform.isLinux || Platform.isMacOS) return;
    try {
      await overlayChannel.invokeMethod('showOverlay');
    } on PlatformException catch (e) {
      print("Failed to show overlay: '${e.message}'.");
    }
  }

  static void requestNativePermissions() async {
    // Skip permission requests for Linux and macOS since accessibility features are disabled
    if (Platform.isLinux || Platform.isMacOS) return;
    try {
      await overlayChannel.invokeMethod('requestNativePermissions');
    } on PlatformException catch (e) {
      print("Failed to request native permissions: '${e.message}'.");
    }
  }

  static Future<bool> isAccessibilityGranted() async {
    // Always return true for Linux and macOS since we're not using accessibility features
    if (Platform.isLinux || Platform.isMacOS) return true;
    try {
      final bool isGranted = await overlayChannel.invokeMethod('isAccessabilityGranted');
      return isGranted;
    } on PlatformException catch (e) {
      print("Failed to check if accessibility is granted: '${e.message}'.");
      return false;
    }
  }

  static Future<void> initAccessibility() async {
    // Skip accessibility initialization for Linux and macOS since we're not using accessibility features
    if (Platform.isLinux || Platform.isMacOS) return;
    try {
      await overlayChannel.invokeMethod('initAccessibility');
      print('[Dart] initAccessibility called');
    } on PlatformException catch (e) {
      print("Failed to initialize accessibility: '${e.message}'.");
    }
  }

  /// To parse use
  /// ```
  /// final screenSize = Size(result['width']!.toDouble(), result['height']!.toDouble());
  /// ```
  static Future<Map<String, num>?> getScreenSize() async {
    if (Platform.isLinux) return null;
    try {
      final Map<String, num>? screenSize = await overlayChannel.invokeMapMethod('getScreenSize');
      return screenSize;
    } on PlatformException catch (e) {
      print("Failed to get screen size: '${e.message}'.");
      return null;
    }
  }

  ///  result(["positionX": cursorPosition.x, "positionY": cursorPosition.y])
  static Future<Offset?> getMousePosition() async {
    if (Platform.isLinux) return null;
    try {
      final mousePosition = await overlayChannel.invokeMethod('getMousePosition');
      return mousePosition != null
          ? Offset(mousePosition['positionX']!.toDouble(), mousePosition['positionY']!.toDouble())
          : null;
    } on PlatformException catch (e) {
      print("Failed to get mouse position: '${e.message}'.");
      return null;
    }
  }

  // region snip-to-chat (Phase 0) ---------------------------------------------

  /// Installs the global Cmd+Option+drag event tap on macOS.
  /// Returns `false` if Accessibility permission is not yet granted (the system
  /// prompt is triggered in that case — grant it and call again).
  static Future<bool> startRegionCaptureService() async {
    if (!Platform.isMacOS) return false;
    try {
      final result = await overlayChannel.invokeMethod('startRegionCaptureService');
      return result == true;
    } on PlatformException catch (e) {
      print("Failed to start region capture service: '${e.message}'.");
      return false;
    }
  }

  static Future<void> stopRegionCaptureService() async {
    if (!Platform.isMacOS) return;
    try {
      await overlayChannel.invokeMethod('stopRegionCaptureService');
    } on PlatformException catch (e) {
      print("Failed to stop region capture service: '${e.message}'.");
    }
  }

  static Future<bool> isRegionCaptureAccessibilityGranted() async {
    if (!Platform.isMacOS) return true;
    try {
      return (await overlayChannel.invokeMethod('isRegionCaptureAccessibilityGranted')) == true;
    } on PlatformException catch (e) {
      print("Failed to check accessibility: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> isScreenRecordingGranted() async {
    if (!Platform.isMacOS) return true;
    try {
      return (await overlayChannel.invokeMethod('isScreenRecordingGranted')) == true;
    } on PlatformException catch (e) {
      print("Failed to check screen recording: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> requestScreenRecordingAccess() async {
    if (!Platform.isMacOS) return true;
    try {
      return (await overlayChannel.invokeMethod('requestScreenRecordingAccess')) == true;
    } on PlatformException catch (e) {
      print("Failed to request screen recording: '${e.message}'.");
      return false;
    }
  }

  // region AI Lens (fullscreen frozen-frame mode) -----------------------------

  /// Captures the display under the cursor (raw JPEG bytes) along with its
  /// geometry, scale, the cursor position within it (top-left origin, points),
  /// and the frontmost app/window. Returns null on non-macOS or capture failure.
  ///
  /// Keys: imageBytes (Uint8List), pxWidth, pxHeight, pointWidth, pointHeight,
  /// scale, cursorX, cursorY, focusedApp, bundleId, windowTitle.
  static Future<Map<String, dynamic>?> captureDisplayUnderCursor() async {
    if (!Platform.isMacOS) return null;
    try {
      final res = await overlayChannel.invokeMethod('captureDisplayUnderCursor');
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } on PlatformException catch (e) {
      print("Failed to capture display under cursor: '${e.message}'.");
      return null;
    }
  }

  /// Expands + raises the main window to cover the display under the cursor and
  /// places it above the menu bar/dock for the fullscreen lens.
  static Future<void> enterLensMode() async {
    if (!Platform.isMacOS) return;
    try {
      await overlayChannel.invokeMethod('enterLensMode');
    } on PlatformException catch (e) {
      print("Failed to enter lens mode: '${e.message}'.");
    }
  }

  /// Restores the window's pre-lens frame, level, and collection behavior.
  static Future<void> exitLensMode() async {
    if (!Platform.isMacOS) return;
    try {
      await overlayChannel.invokeMethod('exitLensMode');
    } on PlatformException catch (e) {
      print("Failed to exit lens mode: '${e.message}'.");
    }
  }

  /// Fires a trackpad haptic (Force Touch). [pattern] is one of `generic`,
  /// `alignment`, or `levelChange`. No-op on non-macOS or hardware without a
  /// haptic trackpad — fire-and-forget, never throws to the caller.
  static Future<void> performHaptic([String pattern = 'generic']) async {
    if (!Platform.isMacOS) return;
    try {
      await overlayChannel.invokeMethod('performHaptic', {'pattern': pattern});
    } on PlatformException catch (e) {
      print("Failed to perform haptic: '${e.message}'.");
    }
  }

  // region OCR (native text recognition) ------------------------------------

  /// Runs on-device OCR over [bytes] (encoded PNG/JPEG) using the platform's
  /// native text recognizer (macOS Vision). Returns a map with `text` (full
  /// joined string) and `blocks` (list of `{text, x, y, w, h, confidence}` where
  /// the rect is normalized 0..1, top-left origin). Null on non-macOS or failure.
  static Future<Map<String, dynamic>?> recognizeText(
    Uint8List bytes, {
    List<String>? languages,
    bool fast = false,
  }) async {
    if (!Platform.isMacOS) return null;
    try {
      final res = await overlayChannel.invokeMethod('recognizeText', {
        'imageBytes': bytes,
        if (languages != null && languages.isNotEmpty) 'languages': languages,
        'fast': fast,
      });
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } on PlatformException catch (e) {
      print("Failed to recognize text: '${e.message}'.");
      return null;
    }
  }

  // Currenlty only used for macOS
  static Future<bool> requestMicrophonePermissions() async {
    if (Platform.isLinux) return true;
    try {
      final result = await overlayChannel.invokeMethod('requestMicrophonePermissions');
      if (result == true) {
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      print("Failed to request microphone permissions: '${e.message}'.");
    }
    return false;
  }
}

/// Will not work on Linux
Future<void> simulateCtrlCKeyPress() async {
  if (Platform.isLinux) return;
  const key = PhysicalKeyboardKey.keyC;
  final modifiers = Platform.isMacOS ? [ModifierKey.metaModifier] : [ModifierKey.controlModifier];
  await keyPressSimulator.simulateKeyDown(key, modifiers);
  await keyPressSimulator.simulateKeyUp(key, modifiers);
}

/// Will not work on Linux
Future<void> simulateCtrlVKeyPress() async {
  if (Platform.isLinux) return;
  const key = PhysicalKeyboardKey.keyV;
  final modifiers = Platform.isMacOS ? [ModifierKey.metaModifier] : [ModifierKey.controlModifier];
  await keyPressSimulator.simulateKeyDown(key, modifiers);
  await keyPressSimulator.simulateKeyUp(key, modifiers);
  log('Simulated Ctrl+V key press');
}
