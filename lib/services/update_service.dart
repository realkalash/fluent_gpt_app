import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final String publishedAt;
  final int downloadSize;
  final bool isPrerelease;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
    required this.downloadSize,
    required this.isPrerelease,
  });

  factory UpdateInfo.fromJson(
      Map<String, dynamic> json, String downloadUrl, int size) {
    return UpdateInfo(
      version: json['tag_name'] ?? '',
      downloadUrl: downloadUrl,
      releaseNotes: json['body'] ?? '',
      publishedAt: json['published_at'] ?? '',
      downloadSize: size,
      isPrerelease: json['prerelease'] ?? false,
    );
  }
}

class UpdateService {
  static const String _repoOwner = 'realkalash';
  static const String _repoName = 'fluent_gpt_app';
  static const String _apiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  static UpdateService? _instance;
  static UpdateService get instance => _instance ??= UpdateService._();
  UpdateService._();

  String? _currentVersion;
  UpdateInfo? _lastCheckResult;
  DateTime? _lastCheckTime;

  /// Check for updates from GitHub releases
  Future<UpdateInfo?> checkForUpdates({bool forceCheck = false}) async {
    try {
      // Don't check more than once every hour unless forced
      if (!forceCheck && _lastCheckTime != null) {
        final timeSinceLastCheck = DateTime.now().difference(_lastCheckTime!);
        if (timeSinceLastCheck.inHours < 1 && _lastCheckResult != null) {
          return _lastCheckResult;
        }
      }

      _lastCheckTime = DateTime.now();

      // Get current version
      if (_currentVersion == null) {
        final packageInfo = await PackageInfo.fromPlatform();
        _currentVersion = 'v${packageInfo.version}';
      }

      // Fetch latest release from GitHub
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'FluentGPT-UpdateChecker',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch releases: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final latestVersion = data['tag_name'] as String? ?? '';

      // Check if we have a newer version
      if (!_isNewerVersion(latestVersion, _currentVersion!)) {
        _lastCheckResult = null;
        return null;
      }

      // Find the appropriate download URL for current platform
      final assets = data['assets'] as List<dynamic>? ?? [];
      final downloadInfo = _getDownloadInfoForPlatform(assets);

      if (downloadInfo == null) {
        throw Exception('No compatible installer found for this platform');
      }

      _lastCheckResult = UpdateInfo.fromJson(
        data,
        downloadInfo['url']!,
        downloadInfo['size']!,
      );

      return _lastCheckResult;
    } catch (e) {
      print('Update check failed: $e');
      _lastCheckResult = null;
      return null;
    }
  }

  /// Download the update file
  Future<String?> downloadUpdate(
    UpdateInfo updateInfo, {
    Function(double progress)? onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = updateInfo.downloadUrl.split('/').last;
      final filePath = '${tempDir.path}/$fileName';

      // Delete existing file if it exists
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Download with progress tracking
      final request = http.Request('GET', Uri.parse(updateInfo.downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download update: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? updateInfo.downloadSize;
      final sink = file.openWrite();
      int downloadedBytes = 0;

      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          downloadedBytes += chunk.length;

          if (onProgress != null && contentLength > 0) {
            final progress = downloadedBytes / contentLength;
            onProgress(progress.clamp(0.0, 1.0));
          }
        },
        onDone: () => sink.close(),
        onError: (error) => sink.close(),
      ).asFuture();

      return filePath;
    } catch (e) {
      print('Download failed: $e');
      return null;
    }
  }

  /// Install the downloaded update
  Future<bool> installUpdate(String filePath) async {
    try {
      if (!await File(filePath).exists()) {
        throw Exception('Update file not found');
      }

      if (Platform.isWindows) {
        return await _installWindows(filePath);
      } else if (Platform.isMacOS) {
        return await _installMacOS(filePath);
      } else {
        throw Exception('Platform not supported for auto-installation');
      }
    } catch (e) {
      print('Installation failed: $e');
      return false;
    }
  }

  /// Open the download page in browser
  Future<void> openDownloadPage() async {
    final url = 'https://github.com/$_repoOwner/$_repoName/releases/latest';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  /// Get current app version
  Future<String> getCurrentVersion() async {
    if (_currentVersion == null) {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = 'v${packageInfo.version}';
    }
    return _currentVersion!;
  }

  /// Compare version strings (assumes semantic versioning)
  bool _isNewerVersion(String latest, String current) {
    // Remove 'v' prefix if present
    latest = latest.replaceFirst('v', '');
    current = current.replaceFirst('v', '');

    final latestParts = latest.split('.').map(int.tryParse).toList();
    final currentParts = current.split('.').map(int.tryParse).toList();

    // Ensure both have at least 3 parts (major.minor.patch)
    while (latestParts.length < 3) latestParts.add(0);
    while (currentParts.length < 3) currentParts.add(0);

    for (int i = 0; i < 3; i++) {
      final latestPart = latestParts[i] ?? 0;
      final currentPart = currentParts[i] ?? 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }

    return false; // Versions are equal
  }

  /// Get platform-specific download info
  Map<String, dynamic>? _getDownloadInfoForPlatform(List<dynamic> assets) {
    String? targetExtension;

    if (Platform.isWindows) {
      targetExtension = '.exe';
    } else if (Platform.isMacOS) {
      targetExtension = '.dmg';
    } else {
      return null; // Unsupported platform
    }

    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.toLowerCase().endsWith(targetExtension)) {
        return {
          'url': asset['browser_download_url'] as String,
          'size': asset['size'] as int,
          'name': name,
        };
      }
    }

    return null;
  }

  /// Install on Windows (Inno Setup .exe installer)
  Future<bool> _installWindows(String exePath) async {
    try {
      // Launch Inno Setup installer with silent mode
      final result = await Process.run(
        exePath,
        // ['/SILENT', '/NORESTART'],
        [],
        runInShell: false,
      );

      return result.exitCode == 0;
    } catch (e) {
      print('Windows installation failed: $e');
      return false;
    }
  }

  /// Install on macOS
  Future<bool> _installMacOS(String dmgPath) async {
    try {
      // Mount the DMG
      final mountResult =
          await Process.run('hdiutil', ['attach', dmgPath, '-nobrowse']);
      if (mountResult.exitCode != 0) {
        throw Exception('Failed to mount DMG');
      }

      // Find the mounted volume
      final mountOutput = mountResult.stdout as String;
      final volumePath = _extractVolumePath(mountOutput);

      if (volumePath == null) {
        throw Exception('Could not find mounted volume');
      }

      // Find the .app file in the volume
      final volumeDir = Directory(volumePath);
      final appFile = await _findAppFile(volumeDir);

      if (appFile == null) {
        throw Exception('Could not find .app file in DMG');
      }

      // Copy to Applications folder
      final appsDir = Directory('/Applications');
      final targetPath = '${appsDir.path}/${appFile.uri.pathSegments.last}';

      // Remove existing app if it exists
      final existingApp = Directory(targetPath);
      if (await existingApp.exists()) {
        await existingApp.delete(recursive: true);
      }

      // Copy new app
      final copyResult =
          await Process.run('cp', ['-R', appFile.path, appsDir.path]);

      // Unmount the DMG
      await Process.run('hdiutil', ['detach', volumePath]);

      return copyResult.exitCode == 0;
    } catch (e) {
      print('macOS installation failed: $e');
      return false;
    }
  }

  String? _extractVolumePath(String mountOutput) {
    final lines = mountOutput.split('\n');
    for (final line in lines) {
      if (line.contains('/Volumes/')) {
        final parts = line.split('\t');
        return parts.last.trim();
      }
    }
    return null;
  }

  Future<Directory?> _findAppFile(Directory volumeDir) async {
    await for (final entity in volumeDir.list()) {
      if (entity is Directory && entity.path.endsWith('.app')) {
        return entity;
      }
    }
    return null;
  }
}
