import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:flutter/foundation.dart';

class ServerProvider extends ChangeNotifier {
  String modelPath = 'http://localhost:5000'; // Update with your server URL
  bool isRunning = false;

  ServerProvider() {
    init();
  }

  void init() {
    modelPath = AppCache.localApiModelPath.value ?? '';
  }

  Future<void> addLocalModelPath(String? path) async {
    if (path == null || path.isEmpty == true) return;
    modelPath = path;
    AppCache.localApiModelPath.value = path;
    notifyListeners();
  }

  Future<void> removeLocalModelPath(String path) async {
    if (modelPath == path) {
      modelPath = '';
      AppCache.localApiModelPath.value = '';
    }
    notifyListeners();
  }

  Future<void> loadModel(String path) async {


  }

  Future<void> stopModel(String path) async {

  }

  Future<bool> isModelRunning(String path) async {
    return false;
  }

  Future<bool> toggleLocalFirstModel(bool value) async {
    if (modelPath.isEmpty == true) {
      return false;
    }
    if (value == true) {
      await loadModel(modelPath);
    } else {
      await stopModel(modelPath);
    }
    isRunning = value;
    notifyListeners();
    return true;
  }
}
