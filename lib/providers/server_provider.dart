import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/local.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/log.dart' as fluentlog;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

class ServerProvider extends ChangeNotifier {
  /// Hugging face model path or local model path
  static String modelPath = 'Qwen/Qwen2.5-1.5B-Instruct-GGUF:Q5_K_M';

  // Server configuration parameters
  int? ctxSize = AppCache.localServerCtxSize.value;
  int? nPredict;
  bool flashAttention = false;
  int? numberOfThreads;
  String? device = AppCache.localServerDevice.value;
  int? batchSize;
  int? gpuLayers;
  static final _isRunningStreamController = StreamController<bool>.broadcast();

  // Llama server related shell process
  static Process? _llamaServerProcess;
  static bool _isServerRunning = false;

  static const String serverHost = 'localhost';
  static int serverPort = AppCache.localServerPort.value ?? 1235;
  static String serverUrl = 'http://$serverHost:$serverPort';
  static final _serverStatusStrController = StreamController<bool>.broadcast();
  static final serverOutputStream = BehaviorSubject<String>();

  /// stream for listening is current shell is running
  static Stream<bool> get isRunningStream => _isRunningStreamController.stream;

  /// stream for listening to llama server status
  static Stream<bool> get serverStatusStream => _serverStatusStrController.stream;

  /// Check if llama server is running
  static bool get isServerRunning => _isServerRunning;
  ServerProvider() {
    init();
  }

  void init() {
    if (AppCache.localApiModelPath.value != null && AppCache.localApiModelPath.value!.isNotEmpty) {
      modelPath = AppCache.localApiModelPath.value!;
    }
  }

  static String getServerPath() {
    var fs = const LocalFileSystem();
    final currentDir = fs.currentDirectory.path;
    return '$currentDir\\plugins\\cpp_build_win\\llama-server.exe';
  }

  static void log(String message, {bool logToDebugger = false}) {
    fluentlog.log(message);
    // final currentTime = DateTime.now().toIso8601String();
    final currentOutput = serverOutputStream.valueOrNull;
    final lines = currentOutput?.split('\n') ?? [];

    /// we save only last 500 lines
    if (lines.length > 500) {
      lines.removeAt(0);
    }
    lines.add(message);
    final appendedOutput = lines.join('\n');
    serverOutputStream.add(appendedOutput);
  }

  /// Start the llama server with the specified model
  static Future<bool> startLlamaServer({
    String? modelPath,
    String? hfModelPath,

    /// size of the prompt context. In other words, the amount of tokens that the LLM can remember at once. Increasing the context size also increases the memory requirements for the LLM. Every model has a context size limit, when this argument is set to 0, llama.cpp tries to use it.
    int? ctxSize,

    /// number of tokens to predict. When LLM generates text, it stops either after generating end-of-message token (when it decides that the generated sentence is over), or after hitting this limit. Default is -1, which makes the LLM generate text ad infinitum. If we want to limit it to context size, we can set it to -2.
    int? nPredict,

    /// Flash attention is an optimization that’s supported by most recent models. Read the linked article for details, in short - enabling it should improve the generation performance for some models. llama.cpp will simply throw a warning when a model that doesn’t support flash attention is loaded, so i keep it on at all times without any issues.
    bool flashAttention = false,

    /// amount of CPU threads used by LLM. Default value is -1, which tells llama.cpp to detect the amount of cores in the system. This behavior is probably good enough for most of people, so unless you have exotic hardware setup and you know what you’re doing - leave it on default. If you do have an exotic setup, you may also want to look at other NUMA and offloading-related flags.
    int? numberOfThreads,

    /// --device "Vulkan0" usually works well, but if you have multiple GPUs, you may want to look at --split-mode and --main-gpu arguments.
    String? device,

    /// amount of tokens fed to the LLM in single processing step. Optimal value of those arguments depends on your hardware, model, and context size - i encourage experimentation, but defaults are probably good enough for start.
    int? batchSize,

    /// if GPU offloading is available, this parameter will set the maximum amount of LLM layers to offload to GPU. Number and size of layers is dependent on the used model. Usually, if we want to load the whole model to GPU, we can set this parameter to some unreasonably large number like 999. For partial offloading, you must experiment yourself. llama.cpp must be built with GPU support, otherwise this option will have no effect. If you have multiple GPUs, you may also want to look at --split-mode and --main-gpu arguments.
    int? gpuLayers,
    bool disableLogging = false,
  }) async {
    if (_isServerRunning) {
      log('Server is already running');
      return true;
    }

    if (modelPath == null && hfModelPath == null) {
      log('No model path provided');
      return false;
    }

    try {
      log('Starting llama server with model: $modelPath');
      if (device != null && gpuLayers == null) {
        log('GPU device is set, but gpuLayers is not set. Setting gpuLayers to 999 (ALL)');
        gpuLayers = 999;
      }
      if (device == null && gpuLayers != null) {
        log('GPU device is not set, but gpuLayers is set. Setting device to CPU');
        gpuLayers = null;
      }

      // Get the absolute path to the cpp_build directory
      final serverPath = getServerPath();

      // Check if server executable exists
      if (!await File(serverPath).exists()) {
        log('Llama server executable not found at: $serverPath');
        return false;
      }

      // Start the server process
      _llamaServerProcess = await Process.start(
        serverPath,
        [
          if (modelPath != null) '-m',
          if (modelPath != null) modelPath,
          if (hfModelPath != null) '-hf',
          if (hfModelPath != null) hfModelPath,
          '--host',
          serverHost,
          '--port',
          serverPort.toString(),
          '--jinja',
          if (flashAttention) '-fa',
          if (numberOfThreads != null) '--threads',
          if (numberOfThreads != null) numberOfThreads.toString(),
          if (device != null) '--device',
          if (device != null) device,
          if (ctxSize != null) '--ctx-size',
          if (ctxSize != null) ctxSize.toString(),
          if (nPredict != null) '--predict',
          if (nPredict != null) nPredict.toString(),
          if (batchSize != null) '--batch-size',
          if (batchSize != null) batchSize.toString(),
          if (gpuLayers != null) '--gpu-layers',
          if (gpuLayers != null) gpuLayers.toString(),
          if (disableLogging) '--log-disable',
          // '--offline',
        ],
      );

      if (_llamaServerProcess != null) {
        _isServerRunning = true;
        _serverStatusStrController.add(true);

        // Listen to server output
        _llamaServerProcess!.stdout.transform(utf8.decoder).listen((data) {
          log(data, logToDebugger: false);
        });

        _llamaServerProcess!.stderr.transform(utf8.decoder).listen((data) {
          log(data, logToDebugger: false);
        });

        // Wait a bit for server to start up
        await Future.delayed(const Duration(seconds: 10));

        // Test server health
        var isHealthy = await _checkServerHealth();

        for (var i = 0; i < 100; i++) {
          if (isHealthy) {
            break;
          } else {
            await Future.delayed(const Duration(seconds: 3));
            isHealthy = await _checkServerHealth();
          }
        }
        if (!isHealthy) {
          log('Server failed health check');
          await stopLlamaServer();
          return false;
        }

        log('Llama server started successfully');
        return true;
      }
    } catch (e) {
      log('Error starting llama server: $e');
      _isServerRunning = false;
      _serverStatusStrController.add(false);
    }

    return false;
  }

  Future<Map<String, String>> getListDevices() async {
    final newProcess = await Process.start(
      getServerPath(),
      [
        '--list-devices',
        '--offline',
      ],
    );
    final output = await newProcess.stdout.transform(utf8.decoder).join();
    final clearString = output.replaceAll("Available devices:", '');
    // Vulkan0: NVIDIA GeForce RTX 3070 Ti (8018 MiB, 8018 MiB free)
    // Vulkan1: NVIDIA GeForce RTX 2070 Ti (8018 MiB, 8018 MiB free)
    final listStrings = clearString.split('\n');
    // remove empty lines
    listStrings.removeWhere((element) => element.trimLeft().isEmpty);
    final map = <String, String>{};
    for (var item in listStrings) {
      final parts = item.split(':');
      map[parts[0].trimLeft()] = parts[1].trim();
    }
    log(map.toString());
    return map;
  }

  /// Stop the llama server
  static Future<void> stopLlamaServer() async {
    if (_llamaServerProcess != null) {
      log('Stopping llama server');
      _llamaServerProcess!.kill();
    }

    _isServerRunning = false;
    _serverStatusStrController.add(false);
    if (_llamaServerProcess != null) {
      // if we actually stopped the server log it
      log('Llama server stopped');
    }
    _llamaServerProcess = null;
  }

  /// Check if the server is healthy and responding
  static Future<bool> _checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      log('Health check failed: $e');
      return false;
    }
  }

  /// Send a chat completion request to the llama server
  static Future<String> sendChatMessage(String message, {List<Map<String, String>>? conversationHistory}) async {
    if (!_isServerRunning) {
      throw Exception('Llama server is not running');
    }

    try {
      // Build messages array
      final messages = <Map<String, String>>[];

      // Add conversation history if provided
      if (conversationHistory != null) {
        messages.addAll(conversationHistory);
      }

      // Add current user message
      messages.add({'role': 'user', 'content': message});

      final requestBody = {
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 2048,
        'stream': false,
      };

      log('Sending chat request: $message');

      final response = await http
          .post(
            Uri.parse('$serverUrl/v1/chat/completions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final content = responseData['choices']?[0]?['message']?['content'] ?? '';
        log('Chat response received: ${content.length} characters');
        return content;
      } else {
        log('Chat request failed with status: ${response.statusCode}');
        log('Response body: ${response.body}');
        throw Exception('Chat request failed: ${response.statusCode}');
      }
    } catch (e) {
      log('Error sending chat message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  void clearOutput() {
    serverOutputStream.add('Cleared output');
  }

  static Timer? _autoStopServerTimer;

  static void autoStopServerChanged(bool? shouldAutoStop) {
    if (shouldAutoStop == null) return;
    AppCache.autoStopServerEnabled.value = shouldAutoStop;
    if (shouldAutoStop) {
      _autoStopServerTimer = Timer.periodic(Duration(minutes: AppCache.autoStopServerAfter.value ?? 10), (timer) {
        stopLlamaServer();
      });
    } else {
      _autoStopServerTimer?.cancel();
    }
  }

  static void autoStopServerValueChanged(int? parsed) {
    if (parsed == null) return;
    AppCache.autoStopServerAfter.value = parsed;
    if (AppCache.autoStopServerEnabled.value ?? false) {
      _autoStopServerTimer?.cancel();
      _autoStopServerTimer = Timer.periodic(Duration(minutes: parsed), (timer) {
        stopLlamaServer();
      });
    }
  }

  static void resetAutoStopTimer() {
    _autoStopServerTimer?.cancel();
    _autoStopServerTimer = Timer.periodic(Duration(minutes: AppCache.autoStopServerAfter.value ?? 10), (timer) {
      stopLlamaServer();
    });
  }
}
