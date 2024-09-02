import 'dart:convert';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ServerProvider extends ChangeNotifier {
  /// <Path, isRunning>
  Map<String, bool> localModelsPaths = {};

  final String serverUrl = 'http://localhost:5000'; // Update with your server URL

  ServerProvider() {
    init();
  }

  void init() {
    final modelsJson = AppCache.localApiModelPaths.value!;
    final paths = jsonDecode(modelsJson) as Map;
    for (var el in paths.entries) {
      localModelsPaths[el.key] = false;
    }
  }

  Future<void> addLocalModelPath(String? path) async {
    if (path == null || path.isEmpty == true) return;
    localModelsPaths[path] = false;
    AppCache.localApiModelPaths.set(jsonEncode(localModelsPaths));
    notifyListeners();
  }

  Future<void> removeLocalModelPath(String path) async {
    localModelsPaths.remove(path);
    AppCache.localApiModelPaths.set(jsonEncode(localModelsPaths));
    notifyListeners();
  }

  Future<void> loadModel(String path) async {
    final response = await http.post(
      Uri.parse('$serverUrl/load_model'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'model_path': path}),
    );

    if (response.statusCode == 200) {
      localModelsPaths[path] = true;
      notifyListeners();
    } else {
      throw Exception('Failed to load model');
    }
  }

  Future<void> stopModel(String path) async {
    final response = await http.post(
      Uri.parse('$serverUrl/stop_model'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      localModelsPaths[path] = false;
      notifyListeners();
    } else {
      throw Exception('Failed to stop model');
    }
  }

  Future<bool> isModelRunning(String path) async {
    final response = await http.post(
      Uri.parse('$serverUrl/is_model_running'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'model_path': path}),
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      return result['is_running'];
    } else {
      throw Exception('Failed to check if model is running');
    }
  }
}