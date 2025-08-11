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
