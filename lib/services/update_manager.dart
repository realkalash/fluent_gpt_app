import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dialogs/update_dialog.dart';
import 'update_service.dart';
import '../main.dart'; // Import to access navigatorKey

class UpdateManager {
  static UpdateManager? _instance;
  static UpdateManager get instance => _instance ??= UpdateManager._();
  UpdateManager._();

  Timer? _periodicTimer;
  bool _isCheckingForUpdates = false;
  
  // Settings keys
  static const String _keyAutoCheckEnabled = 'auto_check_updates';
  static const String _keyCheckIntervalHours = 'update_check_interval';
  static const String _keyLastCheckTime = 'last_update_check';
  static const String _keySkippedVersion = 'skipped_version';
  static const String _keyNotifyOnStartup = 'notify_updates_startup';

  // Default settings
  static const bool _defaultAutoCheck = true;
  static const int _defaultCheckIntervalHours = 24;
  static const bool _defaultNotifyOnStartup = true;

  /// Initialize the update manager
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check for updates on startup if enabled
    if (prefs.getBool(_keyNotifyOnStartup) ?? _defaultNotifyOnStartup) {
      await Future.delayed(const Duration(seconds: 5)); // Wait for app to settle
      await checkForUpdatesNow(silent: true);
    }

    // Start periodic checking if enabled
    await _startPeriodicChecking();
  }

  /// Start periodic update checking
  Future<void> _startPeriodicChecking() async {
    await _stopPeriodicChecking();

    final prefs = await SharedPreferences.getInstance();
    final autoCheckEnabled = prefs.getBool(_keyAutoCheckEnabled) ?? _defaultAutoCheck;
    
    if (!autoCheckEnabled) return;

    final intervalHours = prefs.getInt(_keyCheckIntervalHours) ?? _defaultCheckIntervalHours;
    final interval = Duration(hours: intervalHours);

    _periodicTimer = Timer.periodic(interval, (timer) async {
      await checkForUpdatesNow(silent: true);
    });
  }

  /// Stop periodic update checking
  Future<void> _stopPeriodicChecking() async {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Check for updates now
  Future<void> checkForUpdatesNow({bool silent = false}) async {
    if (_isCheckingForUpdates) return;
    
    _isCheckingForUpdates = true;

    try {
      final updateInfo = await UpdateService.instance.checkForUpdates(forceCheck: !silent);
      
      if (updateInfo != null) {
        await _saveLastCheckTime();
        
        // Check if user has skipped this version
        final prefs = await SharedPreferences.getInstance();
        final skippedVersion = prefs.getString(_keySkippedVersion);
        
        if (skippedVersion == updateInfo.version && silent) {
          // User has skipped this version, don't show dialog
          return;
        }

        // Show update dialog using global navigator
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          await UpdateDialog.show(context, updateInfo);
        }
      } else {
        await _saveLastCheckTime();
        
        if (!silent) {
          // Show "no updates" message
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            _showNoUpdatesDialog(context);
          }
        }
      }

    } catch (e) {
      if (!silent) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          _showErrorDialog(context, e.toString());
        }
      }
    } finally {
      _isCheckingForUpdates = false;
    }
  }

  /// Mark a version as skipped
  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySkippedVersion, version);
  }

  /// Clear skipped version
  Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySkippedVersion);
  }

  /// Get update settings
  Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'autoCheckEnabled': prefs.getBool(_keyAutoCheckEnabled) ?? _defaultAutoCheck,
      'checkIntervalHours': prefs.getInt(_keyCheckIntervalHours) ?? _defaultCheckIntervalHours,
      'notifyOnStartup': prefs.getBool(_keyNotifyOnStartup) ?? _defaultNotifyOnStartup,
      'lastCheckTime': prefs.getString(_keyLastCheckTime),
      'skippedVersion': prefs.getString(_keySkippedVersion),
    };
  }

  /// Update settings
  Future<void> updateSettings({
    bool? autoCheckEnabled,
    int? checkIntervalHours,
    bool? notifyOnStartup,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (autoCheckEnabled != null) {
      await prefs.setBool(_keyAutoCheckEnabled, autoCheckEnabled);
    }
    
    if (checkIntervalHours != null) {
      await prefs.setInt(_keyCheckIntervalHours, checkIntervalHours);
    }
    
    if (notifyOnStartup != null) {
      await prefs.setBool(_keyNotifyOnStartup, notifyOnStartup);
    }

    // Restart periodic checking with new settings
    await _startPeriodicChecking();
  }

  /// Save last check time
  Future<void> _saveLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastCheckTime, DateTime.now().toIso8601String());
  }

  /// Show "no updates available" dialog
  void _showNoUpdatesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const UpdateCheckResultDialog(
        title: 'No Updates Available',
        message: 'You are already using the latest version of Fluent GPT App.',
        isError: false,
      ),
    );
  }

  /// Show error dialog
  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => UpdateCheckResultDialog(
        title: 'Update Check Failed',
        message: 'Failed to check for updates: $error',
        isError: true,
      ),
    );
  }

  /// Dispose of resources
  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }
}

/// Simple dialog for showing update check results using Fluent UI
class UpdateCheckResultDialog extends StatelessWidget {
  final String title;
  final String message;
  final bool isError;

  const UpdateCheckResultDialog({
    super.key,
    required this.title,
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    
    return ContentDialog(
      title: Row(
        children: [
          Icon(
            isError ? FluentIcons.error : FluentIcons.check_mark,
            color: isError ? Colors.red : Colors.green,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
} 