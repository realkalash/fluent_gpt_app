import 'package:flutter/foundation.dart';
import '../services/update_service.dart';
import '../services/update_manager.dart';

/// Helper class for testing the update system
/// Only use this for development and testing
class UpdateTestHelper {
  
  /// Test the update checking functionality
  static Future<void> testUpdateCheck() async {
    if (!kDebugMode) {
      print('Update testing is only available in debug mode');
      return;
    }

    print('🔍 Testing update check...');
    
    try {
      final currentVersion = await UpdateService.instance.getCurrentVersion();
      print('📋 Current version: $currentVersion');
      
      final updateInfo = await UpdateService.instance.checkForUpdates(forceCheck: true);
      
      if (updateInfo != null) {
        print('✅ Update available!');
        print('   Version: ${updateInfo.version}');
        print('   Download URL: ${updateInfo.downloadUrl}');
        print('   Size: ${_formatBytes(updateInfo.downloadSize)}');
        print('   Is Prerelease: ${updateInfo.isPrerelease}');
        print('   Published: ${updateInfo.publishedAt}');
        print('   Release Notes: ${updateInfo.releaseNotes.substring(0, 100)}...');
      } else {
        print('ℹ️ No updates available');
      }
      
    } catch (e) {
      print('❌ Update check failed: $e');
    }
  }

  /// Test the settings functionality
  static Future<void> testSettings() async {
    if (!kDebugMode) {
      print('Settings testing is only available in debug mode');
      return;
    }

    print('⚙️ Testing update settings...');
    
    try {
      final settings = await UpdateManager.instance.getSettings();
      print('📋 Current settings:');
      settings.forEach((key, value) {
        print('   $key: $value');
      });
      
      // Test updating settings
      print('🔄 Testing settings update...');
      await UpdateManager.instance.updateSettings(
        autoCheckEnabled: !settings['autoCheckEnabled'],
        checkIntervalHours: 12,
      );
      
      final newSettings = await UpdateManager.instance.getSettings();
      print('📋 Updated settings:');
      newSettings.forEach((key, value) {
        print('   $key: $value');
      });
      
      // Restore original settings
      await UpdateManager.instance.updateSettings(
        autoCheckEnabled: settings['autoCheckEnabled'],
        checkIntervalHours: settings['checkIntervalHours'],
      );
      
      print('✅ Settings test completed');
      
    } catch (e) {
      print('❌ Settings test failed: $e');
    }
  }

  /// Print debug information about the update system
  static Future<void> printDebugInfo() async {
    if (!kDebugMode) {
      print('Debug info is only available in debug mode');
      return;
    }

    print('🐛 Update System Debug Info');
    print('=' * 40);
    
    try {
      final currentVersion = await UpdateService.instance.getCurrentVersion();
      final settings = await UpdateManager.instance.getSettings();
      
      print('Current Version: $currentVersion');
      print('Settings:');
      settings.forEach((key, value) {
        print('  $key: $value');
      });
      
      print('GitHub API URL: https://api.github.com/repos/realkalash/fluent_gpt_app/releases/latest');
      print('Repository: realkalash/fluent_gpt_app');
      
    } catch (e) {
      print('❌ Failed to get debug info: $e');
    }
    
    print('=' * 40);
  }

  /// Format bytes to human readable string
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Simulate an update notification (for testing UI)
  static Future<void> simulateUpdateNotification() async {
    if (!kDebugMode) {
      print('Update simulation is only available in debug mode');
      return;
    }

    print('🔔 Simulating update notification...');
    
    // Create a fake update info for testing
    final fakeUpdateInfo = UpdateInfo(
      version: 'v1.0.999',
      downloadUrl: 'https://example.com/fake-download.msi',
      releaseNotes: '''
# Test Update v1.0.999

## What's New
- Test feature 1
- Test feature 2
- Bug fixes and improvements

## Notes
This is a simulated update for testing purposes only.
      ''',
      publishedAt: DateTime.now().toIso8601String(),
      downloadSize: 50 * 1024 * 1024, // 50 MB
      isPrerelease: false,
    );

    print('📋 Fake update info created:');
    print('   Version: ${fakeUpdateInfo.version}');
    print('   Size: ${_formatBytes(fakeUpdateInfo.downloadSize)}');
    
    // Note: You would need to manually show the dialog with this fake data
    // since we can't access the context from here
    print('ℹ️ Use this data to manually test the UpdateDialog UI');
  }
} 