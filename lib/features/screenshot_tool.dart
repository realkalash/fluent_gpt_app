import 'dart:io';

class ScreenshotTool {

  Future<File?> takeScreenshot() async {
    try {
      // Path to the Python script
      String scriptPath = 'capture_screenshot.py';

      // Run the Python script
      ProcessResult result = await Process.run('python', [scriptPath]);

      if (result.exitCode == 0) {
        // Screenshot captured successfully
        String filePath = result.stdout.toString().trim();
        return File(filePath);
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
