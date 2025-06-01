import 'package:flutter/foundation.dart';
import 'utils/update_test_helper.dart';

/// Simple function to test updates during development
/// Call this from anywhere in your app during debugging
Future<void> debugTestUpdates() async {
  if (!kDebugMode) return;
  
  print('🧪 Starting update system test...');
  
  // Test the update check
  await UpdateTestHelper.testUpdateCheck();
  
  // Print debug info
  await UpdateTestHelper.printDebugInfo();
  
  // Test settings
  await UpdateTestHelper.testSettings();
} 