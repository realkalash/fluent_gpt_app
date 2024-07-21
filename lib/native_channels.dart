// ignore_for_file: avoid_print

import 'package:flutter/services.dart';

const overlayChannel = MethodChannel('com.realk.fluent_gpt/overlay');

class NativeChannelUtils {
  static void testChannel() async {
    try {
      final result = await overlayChannel.invokeMethod('testResultFromSwift');
      print('Result from Swift: $result');
    } on PlatformException catch (e) {
      print("Failed to get result from Swift: '${e.message}'.");
    }
  }

  static Future<String?> getSelectedText() async {
    try {
      final String? selectedText =
          await overlayChannel.invokeMethod('getSelectedText');
      print(
          '[Dart] Selected text from clipboard: ${selectedText ?? "No text selected"}');
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
    try {
      await overlayChannel.invokeMethod('showOverlay');
    } on PlatformException catch (e) {
      print("Failed to show overlay: '${e.message}'.");
    }
  }

  static void requestNativePermissions() async {
    try {
      await overlayChannel.invokeMethod('requestNativePermissions');
    } on PlatformException catch (e) {
      print("Failed to request native permissions: '${e.message}'.");
    }
  }

  static Future<bool> isAccessibilityGranted() async {
    try {
      final bool isGranted =
          await overlayChannel.invokeMethod('isAccessabilityGranted');
      return isGranted;
    } on PlatformException catch (e) {
      print("Failed to check if accessibility is granted: '${e.message}'.");
      return false;
    }
  }

  static void initAccessibility() async {
    try {
      await overlayChannel.invokeMethod('initAccessibility');
      print('[Dart] initAccessibility called');
    } on PlatformException catch (e) {
      print("Failed to initialize accessibility: '${e.message}'.");
    }
  }

  static Future<Map<String, num>?> getScreenSize() async {
    try {
      final Map<String, num>? screenSize =
          await overlayChannel.invokeMapMethod('getScreenSize');
      return screenSize;
    } on PlatformException catch (e) {
      print("Failed to get screen size: '${e.message}'.");
      return null;
    }
  }

  ///  result(["positionX": cursorPosition.x, "positionY": cursorPosition.y])
  static Future<Offset?> getMousePosition() async {
    try {
      final mousePosition =
          await overlayChannel.invokeMethod('getMousePosition');
      return mousePosition != null
          ? Offset(mousePosition['positionX']!.toDouble(), mousePosition['positionY']!.toDouble())
          : null;
    } on PlatformException catch (e) {
      print("Failed to get mouse position: '${e.message}'.");
      return null;
    }
  }
}
