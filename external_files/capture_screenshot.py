import sys
from datetime import datetime
from PyQt5.QtWidgets import QApplication, QWidget
from PyQt5.QtGui import QPainter, QColor, QPen, QGuiApplication
from PyQt5.QtCore import Qt, QRect

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

    def takeScreenshot(self):
        x1 = min(self.start_point.x(), self.end_point.x())
        y1 = min(self.start_point.y(), self.end_point.y())
        x2 = max(self.start_point.x(), self.end_point.x())
        y2 = max(self.start_point.y(), self.end_point.y())
        screen = QGuiApplication.primaryScreen()
        screenshot = screen.grabWindow(0, x1, y1, x2 - x1, y2 - y1)
        file_name = f'screenshot_{datetime.now().strftime("%Y%m%d_%H%M%S")}.jpg'
        screenshot.save(file_name, 'jpg')
        print(file_name)  # Print the file name to stdout

if __name__ == '__main__':
    app = QApplication(sys.argv)
    ex = ScreenshotApp()
    sys.exit(app.exec_())