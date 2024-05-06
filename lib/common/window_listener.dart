import 'package:chatgpt_windows_flutter_app/common/prefs/app_cache.dart';
import 'package:chatgpt_windows_flutter_app/log.dart';
import 'package:window_manager/window_manager.dart';

class AppWindowListener extends WindowListener {
  //single instance
  static final AppWindowListener _instance = AppWindowListener._internal();

  factory AppWindowListener() {
    return _instance;
  }

  AppWindowListener._internal();

  @override
  Future<void> onWindowMoved() async {
    final offset = await windowManager.getPosition();
    log('Window moved. Position: $offset');
    AppCache.windowX.set(offset.dx.toInt());
    AppCache.windowY.set(offset.dy.toInt());
  }

  @override
  Future<void> onWindowResized() async {
    final size = await windowManager.getSize();
    log('Window resized. Size: $size');
    AppCache.windowWidth.set(size.width.toInt());
    AppCache.windowHeight.set(size.height.toInt());
  }
}
