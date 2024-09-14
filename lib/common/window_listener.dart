import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
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
    if (overlayVisibility.value.isEnabled) {
      return;
    }
    final offset = await windowManager.getPosition();
    log('Window moved. Position: $offset');
    AppCache.windowX.set(offset.dx.toInt());
    AppCache.windowY.set(offset.dy.toInt());
  }

  @override
  Future<void> onWindowResized() async {
    if (overlayVisibility.value.isEnabled) {
      return;
    }
    final size = await windowManager.getSize();
    log('Window resized. Size: $size');
    AppCache.windowWidth.set(size.width.toInt());
    AppCache.windowHeight.set(size.height.toInt());
  }

  // @override
  // Future<void> onWindowClose() async {
  //   log('Window closed');
  //   windowVisibilityStream.add(false);
  // }

  // @override
  // onWindowMinimize() {
  //   log('Window minimized');
  //   windowVisibilityStream.add(false);
  // }

  // @override
  // onWindowRestore() {
  //   log('Window restored');
  //   windowVisibilityStream.add(true);
  //   // windowManager.focus();
  //   // promptTextFocusNode.requestFocus();
  // }

  @override
  void onWindowEvent(String eventName) {
    log('Window event: $eventName');
    if (eventName == 'show') {
      windowVisibilityStream.add(true);
    } else if (eventName == 'restore') {
      windowVisibilityStream.add(true);
    } else if (eventName == 'hide') {
      windowVisibilityStream.add(false);
    } else if (eventName == 'minimize') {
      windowVisibilityStream.add(false);
    }
  }
}
