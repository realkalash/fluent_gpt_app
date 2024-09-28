import 'dart:io';

import 'package:fluent_gpt/common/attachment.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';

class ScreenshotTool {
  static bool isCapturingState = false;
  static const _fileName = 'capture_screenshot.py';
  static String get filePath =>
      '${FileUtils.externalToolsPath}${Platform.pathSeparator}$_fileName';

  /// If [isStorageAccessGranted] is `false`, the Python script will NOT be copied to the external tools directory.
  static Future<void> init({bool isStorageAccessGranted = false}) async {
    try {
      if (isStorageAccessGranted == false) {
        return;
      }
      if (Platform.isMacOS) {
        // Current script implementation is using fullscreen screenshot,
        // but it's not working on macOS because all windows get minimized using fullscreen mode in macos
        return;
      }
      final file = File(filePath);
      if (!file.existsSync()) {
        await file.create(recursive: true);
        await file.writeAsString(_captureScreenshotPythonFileContent);
      }
    } catch (e, stack) {
      logError('$e', stack);
    }
  }

  static Future<Attachment?> takeScreenshot() async {
    try {
      isCapturingState = true;
      // Run the Python script
      ProcessResult result = await Process.run('python3', [filePath]);
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
      isCapturingState = true;
      // Run the Python script
      ProcessResult result = await Process.run('python3', [filePath]);
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

const _captureScreenshotPythonFileContent = '''
import sys
import base64
import subprocess
from datetime import datetime

def install(package):
    subprocess.check_call([sys.executable, "-m", "pip", "install", package])

try:
    from PyQt5.QtWidgets import QApplication, QWidget
    from PyQt5.QtGui import QPainter, QColor, QPen, QGuiApplication, QPixmap
    from PyQt5.QtCore import Qt, QRect, QBuffer, QByteArray
except ImportError:
    install('PyQt5')
    from PyQt5.QtWidgets import QApplication, QWidget
    from PyQt5.QtGui import QPainter, QColor, QPen, QGuiApplication, QPixmap
    from PyQt5.QtCore import Qt, QRect, QBuffer, QByteArray

from io import BytesIO

class ScreenshotApp(QWidget):
    def __init__(self):
        super().__init__()
        self.start_point = None
        self.end_point = None
        self.initUI()

    def initUI(self):
        self.setWindowTitle('Screenshot App')
        self.setWindowOpacity(0.3)
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)
        self.showFullScreen()
        self.setMouseTracking(True)

    def paintEvent(self, event):
        if self.start_point and self.end_point:
            painter = QPainter(self)
            painter.setPen(QPen(Qt.red, 2, Qt.SolidLine))
            painter.setBrush(QColor(0, 0, 0, 128))
            painter.drawRect(self.rect())
            painter.setCompositionMode(QPainter.CompositionMode_Clear)
            painter.drawRect(QRect(self.start_point, self.end_point))

    def mousePressEvent(self, event):
        self.start_point = event.pos()
        self.end_point = self.start_point
        self.update()

    def mouseMoveEvent(self, event):
        self.end_point = event.pos()
        self.update()

    def mouseReleaseEvent(self, event):
        self.end_point = event.pos()
        self.update()
        self.takeScreenshot()
        self.close()

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.close()

    def takeScreenshot(self):
        x1 = min(self.start_point.x(), self.end_point.x())
        y1 = min(self.start_point.y(), self.end_point.y())
        x2 = max(self.start_point.x(), self.end_point.x())
        y2 = max(self.start_point.y(), self.end_point.y())
        screen = QGuiApplication.primaryScreen()
        screenshot = screen.grabWindow(0, x1, y1, x2 - x1, y2 - y1)
        
        buffer = QByteArray()
        qbuffer = QBuffer(buffer)
        qbuffer.open(QBuffer.WriteOnly)
        screenshot.save(qbuffer, 'jpg')
        
        img_str = base64.b64encode(buffer.data()).decode('utf-8')
        
        print(img_str)  # Print the base64 string to stdout

if __name__ == '__main__':
    app = QApplication(sys.argv)
    ex = ScreenshotApp()
    sys.exit(app.exec_())
''';
