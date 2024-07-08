import 'package:chatgpt_windows_flutter_app/common/prefs/app_cache.dart';
import 'package:chatgpt_windows_flutter_app/log.dart';
import 'package:chatgpt_windows_flutter_app/overlay_manager.dart';
import 'package:chatgpt_windows_flutter_app/pages/home_page.dart';
import 'package:rxdart/rxdart.dart';
import 'package:window_manager/window_manager.dart';

class AppWindowListener extends WindowListener {
  //single instance
  static final AppWindowListener _instance = AppWindowListener._internal();

  /// Stream to listen to window visibility changes
  static BehaviorSubject<bool> windowVisibilityStream =
      BehaviorSubject<bool>.seeded(true);

  factory AppWindowListener() {
    return _instance;
  }

  AppWindowListener._internal();

  @override
  Future<void> onWindowMoved() async {
    if (isShowingOverlay.value) {
      return;
    }
    final offset = await windowManager.getPosition();
    log('Window moved. Position: $offset');
    AppCache.windowX.set(offset.dx.toInt());
    AppCache.windowY.set(offset.dy.toInt());
  }

  @override
  Future<void> onWindowResized() async {
    if (isShowingOverlay.value) {
      return;
    }
    final size = await windowManager.getSize();
    log('Window resized. Size: $size');
    AppCache.windowWidth.set(size.width.toInt());
    AppCache.windowHeight.set(size.height.toInt());
  }

  @override
  Future<void> onWindowClose() async {
    log('Window closed');
    windowVisibilityStream.add(false);
  }

  @override
  onWindowMinimize() {
    log('Window minimized');
    windowVisibilityStream.add(false);
  }

  @override
  onWindowRestore() {
    log('Window restored');
    windowVisibilityStream.add(true);
    windowManager.focus();
    promptTextFocusNode.requestFocus();
  }
}
