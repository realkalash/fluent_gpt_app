import 'dart:io';

import 'package:fluent_gpt/common/attachment.dart';
import 'package:fluent_gpt/log.dart';

class ScreenshotTool {
  static bool isCapturingState = false;
  static Future<Attachment?> takeScreenshot() async {
    try {
      // Path to the Python script
      String scriptPath = 'capture_screenshot.py';

      isCapturingState = true;
      // Run the Python script
      ProcessResult result = await Process.run('python', [scriptPath]);
      isCapturingState = false;
      if (result.exitCode == 0) {
        // Screenshot captured successfully
        String base64StringOutput = result.stdout.toString().trim();
        return Attachment.fromInternalScreenshot(base64StringOutput);
      } else {
        // Handle error
        logError('Error capturing screenshot: ${result.stderr}');
      }
    } catch (e) {
      logError('Exception: $e');
    }
    isCapturingState = false;
    return null;
  }

  static Future<String?> takeScreenshotReturnBase64() async {
    try {
      // Path to the Python script
      String scriptPath = 'capture_screenshot.py';

      isCapturingState = true;
      // Run the Python script
      ProcessResult result = await Process.run('python', [scriptPath]);
      isCapturingState = false;

      if (result.exitCode == 0) {
        // Screenshot captured successfully
        String base64StringOutput = result.stdout.toString().trim();
        return base64StringOutput;
      } else {
        // Handle error
        logError('Error capturing screenshot: ${result.stderr}');
      }
    } catch (e) {
      logError('Exception: $e');
    }
    isCapturingState = false;
    return null;
  }
}
