import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluent_gpt/features/screen_ocr/text_detection_service.dart';
import 'package:fluent_gpt/features/screen_ocr/text_region.dart';
import 'package:fluent_gpt/features/screenshot_tool.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:rxdart/rxdart.dart';
import 'package:window_manager/window_manager.dart';

class ClickToReadTool {
  static bool isActive = false;

  static final BehaviorSubject<Uint8List?> screenshotData =
      BehaviorSubject<Uint8List?>.seeded(null);
  static final BehaviorSubject<List<TextRegion>> detectedRegions =
      BehaviorSubject<List<TextRegion>>.seeded([]);
  static final BehaviorSubject<bool> isDetecting =
      BehaviorSubject<bool>.seeded(false);
  static final BehaviorSubject<String?> statusMessage =
      BehaviorSubject<String?>.seeded(null);

  static String get _tempImagePath =>
      '${FileUtils.appTemporaryDirectoryPath}${Platform.pathSeparator}click_to_read.png';

  static Future<void> init({bool isStorageAccessGranted = false}) async {
    if (!isStorageAccessGranted) return;
    await TextDetectionService.ensureScriptExists();
  }

  static Future<void> activate() async {
    if (isActive) return;
    isActive = true;

    try {
      // Hide window so it doesn't appear in screenshot
      await windowManager.hide();
      await Future.delayed(const Duration(milliseconds: 200));

      // Take screenshot
      final base64Result = (Platform.isMacOS || Platform.isWindows)
          ? await ScreenshotTool.takeScreenshotReturnBase64Native()
          : await ScreenshotTool.takeScreenshotReturnBase64();

      if (base64Result == null || base64Result.isEmpty) {
        log('[ClickToRead] Screenshot failed');
        isActive = false;
        await windowManager.show();
        return;
      }

      // Decode and publish screenshot
      final bytes = base64Decode(base64Result);
      screenshotData.add(Uint8List.fromList(bytes));

      // Save to temp file for Python processing
      final tempFile = File(_tempImagePath);
      await tempFile.parent.create(recursive: true);
      await tempFile.writeAsBytes(bytes);

      // Show fullscreen overlay
      await OverlayManager.showClickToReadOverlay();

      // Run text detection in background
      isDetecting.add(true);
      statusMessage.add(null);
      TextDetectionService.detectTextRegions(
        _tempImagePath,
        onStatus: (msg) => statusMessage.add(msg),
      ).then((result) {
        if (result.hasError) {
          log('[ClickToRead] Error: ${result.error}');
          statusMessage.add(result.error);
        } else {
          log('[ClickToRead] Detected ${result.regions.length} text regions');
          detectedRegions.add(result.regions);
          statusMessage.add(null);
        }
        isDetecting.add(false);
      });
    } catch (e, stack) {
      logError('[ClickToRead] Activation failed: $e', stack);
      isActive = false;
      await windowManager.show();
    }
  }

  static Future<void> dismiss() async {
    if (!isActive) return;
    isActive = false;

    screenshotData.add(null);
    detectedRegions.add([]);
    isDetecting.add(false);
    statusMessage.add(null);

    await OverlayManager.switchToMainWindow();

    // Clean up temp file
    try {
      final tempFile = File(_tempImagePath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {}
  }
}
