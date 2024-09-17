import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:fluent_gpt/common/attachment.dart';

class ScreenshotTool {
  static Future<Attachment?> takeScreenshot() async {
    try {
      // Path to the Python script
      String scriptPath = 'capture_screenshot.py';

      // Run the Python script
      ProcessResult result = await Process.run('python', [scriptPath]);

      if (result.exitCode == 0) {
        // Screenshot captured successfully
        String filePath = result.stdout.toString().trim();
        final bytes = File(filePath).readAsBytesSync();
        return Attachment.fromInternalScreenshot(XFile(
          filePath,
          mimeType: 'image/jpeg',
          bytes: bytes,
          length: bytes.length,
        ));
      } else {
        // Handle error
        print('Error capturing screenshot: ${result.stderr}');
      }
    } catch (e) {
      print('Exception: $e');
    }
    return null;
  }
}
