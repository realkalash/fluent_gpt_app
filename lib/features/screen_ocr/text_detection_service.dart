import 'dart:convert';
import 'dart:io';

import 'package:fluent_gpt/features/screen_ocr/text_region.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';

class TextDetectionResult {
  final List<TextRegion> regions;
  final String? error;

  const TextDetectionResult({this.regions = const [], this.error});

  bool get hasError => error != null;
}

class TextDetectionService {
  static const _scriptFileName = 'detect_text.py';
  /// Version marker — bump this to force-rewrite the script on disk.
  static const _scriptVersion = 2;

  static String get _toolsDir => FileUtils.externalToolsPath!;
  static String get scriptFilePath =>
      '$_toolsDir${Platform.pathSeparator}$_scriptFileName';
  static String get _scriptVersionFile =>
      '$_toolsDir${Platform.pathSeparator}.detect_text_version';
  static String get _venvDir =>
      '$_toolsDir${Platform.pathSeparator}detect_text_venv';
  static String get _venvPython {
    if (Platform.isWindows) {
      return '$_venvDir${Platform.pathSeparator}Scripts${Platform.pathSeparator}python.exe';
    }
    return '$_venvDir${Platform.pathSeparator}bin${Platform.pathSeparator}python3';
  }

  /// Writes the script to disk (or overwrites if the version changed).
  static Future<void> ensureScriptExists() async {
    try {
      final versionFile = File(_scriptVersionFile);
      final currentVersion = versionFile.existsSync()
          ? int.tryParse(versionFile.readAsStringSync().trim()) ?? 0
          : 0;

      if (currentVersion >= _scriptVersion && File(scriptFilePath).existsSync()) {
        return;
      }

      final file = File(scriptFilePath);
      await file.create(recursive: true);
      await file.writeAsString(_detectTextScript);
      await versionFile.create(recursive: true);
      await versionFile.writeAsString('$_scriptVersion');
    } catch (e, stack) {
      logError('Failed to write detect_text.py: $e', stack);
    }
  }

  /// Finds a suitable Python 3 binary. Prefers 3.10-3.12 over bleeding-edge versions
  /// because many native packages don't have wheels for 3.13+.
  static Future<String> _findPython() async {
    // Try specific versions first (most likely to have package support)
    for (final ver in ['python3.12', 'python3.11', 'python3.10', 'python3.13']) {
      try {
        final result = await Process.run(ver, ['--version']);
        if (result.exitCode == 0) {
          log('[TextDetection] Using $ver');
          return ver;
        }
      } catch (_) {}
    }
    // Fall back to default python3
    return 'python3';
  }

  /// Returns true if the venv exists and has the required packages.
  static bool get isVenvReady => File(_venvPython).existsSync();

  /// Creates the venv and installs dependencies. Calls [onStatus] with progress messages.
  static Future<String?> ensureVenvReady({
    void Function(String message)? onStatus,
  }) async {
    if (isVenvReady) {
      // Quick check: can we import the detector?
      final check = await Process.run(
        _venvPython,
        ['-c', 'from comic_text_detector.inference import TextDetector'],
        stderrEncoding: utf8,
      );
      if (check.exitCode == 0) return null;
      // Package missing — fall through to install
    }

    final python = await _findPython();

    // Create venv (delete existing if Python version changed)
    onStatus?.call('Creating Python virtual environment...');
    if (Directory(_venvDir).existsSync()) {
      await Directory(_venvDir).delete(recursive: true);
    }
    final venvResult = await Process.run(
      python,
      ['-m', 'venv', _venvDir],
      stderrEncoding: utf8,
    );
    if (venvResult.exitCode != 0) {
      final err = 'Failed to create Python venv: ${venvResult.stderr}';
      logError(err);
      return err;
    }

    // Upgrade pip first to avoid issues
    await Process.run(
      _venvPython,
      ['-m', 'pip', 'install', '--upgrade', 'pip'],
      stderrEncoding: utf8,
      stdoutEncoding: utf8,
    );

    // Try installing from PyPI first
    onStatus?.call('Installing text detection packages (first run, may take a few minutes)...');
    var pipResult = await Process.run(
      _venvPython,
      ['-m', 'pip', 'install', 'comic-text-detector', 'numpy', 'Pillow'],
      stderrEncoding: utf8,
      stdoutEncoding: utf8,
    );

    // If PyPI fails (no wheels for this Python version), try from GitHub
    if (pipResult.exitCode != 0) {
      log('[TextDetection] PyPI install failed, trying GitHub source...');
      onStatus?.call('PyPI install failed. Trying to install from GitHub source...');
      pipResult = await Process.run(
        _venvPython,
        [
          '-m', 'pip', 'install',
          'git+https://github.com/dmMaze/comic-text-detector.git',
          'numpy', 'Pillow',
        ],
        stderrEncoding: utf8,
        stdoutEncoding: utf8,
      );
    }

    if (pipResult.exitCode != 0) {
      final err = pipResult.stderr.toString();
      logError('Failed to install Python packages: $err');
      return 'Failed to install text detection packages.\n\n'
          'This may be because your Python version is too new.\n'
          'Try installing Python 3.12: brew install python@3.12\n\n'
          '$err';
    }

    onStatus?.call('Text detection packages installed successfully.');
    return null;
  }

  static Future<TextDetectionResult> detectTextRegions(
    String imagePath, {
    void Function(String message)? onStatus,
  }) async {
    try {
      // Ensure venv is ready
      if (!isVenvReady) {
        final error = await ensureVenvReady(onStatus: onStatus);
        if (error != null) {
          return TextDetectionResult(error: error);
        }
      }

      await ensureScriptExists();

      onStatus?.call('Detecting text regions...');
      final result = await Process.run(
        _venvPython,
        [scriptFilePath, imagePath],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      if (result.exitCode != 0) {
        final stderr = result.stderr.toString();
        logError('Text detection failed (exit ${result.exitCode}): $stderr');

        if (stderr.contains('ModuleNotFoundError')) {
          // Try reinstalling
          onStatus?.call('Reinstalling missing packages...');
          final reinstallErr = await ensureVenvReady(onStatus: onStatus);
          if (reinstallErr != null) {
            return TextDetectionResult(error: reinstallErr);
          }
          // Retry once
          return detectTextRegions(imagePath, onStatus: onStatus);
        }

        return TextDetectionResult(error: 'Text detection failed:\n$stderr');
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty || output == '[]') {
        return const TextDetectionResult();
      }

      final List<dynamic> jsonList = jsonDecode(output);
      final regions = jsonList
          .map((e) => TextRegion.fromJson(e as Map<String, dynamic>))
          .toList();
      return TextDetectionResult(regions: regions);
    } on ProcessException catch (e) {
      final msg = 'Python not found. Please install Python 3.10+ and restart the app.';
      logError('$msg: $e');
      return TextDetectionResult(error: msg);
    } catch (e, stack) {
      logError('Text detection error: $e', stack);
      return TextDetectionResult(error: 'Unexpected error: $e');
    }
  }
}

const _detectTextScript = r'''
"""Text detection using comic-text-detector. Called from FluentGPT."""
import sys
import json


def detect(image_path):
    from comic_text_detector.inference import TextDetector
    import numpy as np
    from PIL import Image

    model = TextDetector(detect_model="ctd")
    img = np.array(Image.open(image_path).convert("RGB"))
    text_lines, raw_results = model(img)
    regions = []
    for line in text_lines:
        pts = np.array(line)
        x, y = float(pts[:, 0].min()), float(pts[:, 1].min())
        w = float(pts[:, 0].max()) - x
        h = float(pts[:, 1].max()) - y
        regions.append({
            "x": x,
            "y": y,
            "w": w,
            "h": h,
            "confidence": 1.0,
        })
    print(json.dumps(regions))


if __name__ == "__main__":
    if len(sys.argv) > 1:
        detect(sys.argv[1])
    else:
        print("[]")
''';
