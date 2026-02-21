import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Import for compute
import '../models/app_info.dart';

// Define the name of the channel. This string MUST match the name
// used in the Kotlin code (MainActivity.kt).
const String _channelName = 'com.syafril.fyplauncher/app_manager';

class AppService {
  final MethodChannel _platform = const MethodChannel(_channelName);

  // List to hold all installed applications (used by the Parent view)
  List<AppInfo> allApps = [];

  // -------------------------------------------------------------------------
  // 1. Method to fetch ALL installed apps from the native platform
  // -------------------------------------------------------------------------

  Future<List<AppInfo>> getInstalledApps() async {
    debugPrint('Requesting installed apps from native Kotlin...');
    try {
      // Invoke the method 'getAllApps' on the native side.
      final List<dynamic>? appsList =
      await _platform.invokeMethod('getAllApps');

      if (appsList == null) {
        return [];
      }

      // Convert the raw list (Map<Object?, Object?>) to Map<String, dynamic> safely
      // This fixes the type cast error: type '_Map<Object?,Object?>' is not a subtype of 'Map<String, dynamic>'
      final List<Map<String, dynamic>> safeAppsList = appsList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // We use compute for heavy processing to prevent UI lag.
      // The _parseApps function is defined below.
      final List<AppInfo> apps =
      await compute(_parseApps, safeAppsList);

      // Store the full list for later use (e.g., in the Settings Page)
      allApps = apps;

      debugPrint('Successfully received ${apps.length} apps.');
      return apps;

    } on PlatformException catch (e) {
      debugPrint("Failed to get apps: '${e.message}'.");
      // Return an empty list on failure
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // 2. Method to launch a specific app using its package name
  // -------------------------------------------------------------------------

  Future<void> launchApp(String packageName) async {
    try {
      await _platform.invokeMethod('launchApp', {
        'packageName': packageName
      });
      debugPrint('Attempting to launch $packageName');
    } on PlatformException catch (e) {
      debugPrint("Failed to launch app: '${e.message}'.");
    }
  }

  // -------------------------------------------------------------------------
  // 3. Usage Stats Methods
  // -------------------------------------------------------------------------

  Future<bool> checkUsagePermission() async {
    try {
      final bool granted = await _platform.invokeMethod('checkUsagePermission');
      return granted;
    } on PlatformException catch (e) {
      debugPrint("Failed to check usage permission: '${e.message}'.");
      return false;
    }
  }

  Future<void> requestUsagePermission() async {
    try {
      await _platform.invokeMethod('requestUsagePermission');
    } on PlatformException catch (e) {
      debugPrint("Failed to request usage permission: '${e.message}'.");
    }
  }

  Future<Map<String, int>> getUsageStats() async {
    try {
      final Map<dynamic, dynamic>? usageStats = await _platform.invokeMethod('getUsageStats');
      if (usageStats != null) {
        return usageStats.map((key, value) => MapEntry(key.toString(), value as int));
      }
      return {};
    } on PlatformException catch (e) {
      debugPrint("Failed to get usage stats: '${e.message}'.");
      return {};
    }
  }
  
  // -------------------------------------------------------------------------
  // 4. Wallpaper Method (REMOVED)
  // -------------------------------------------------------------------------

  // -------------------------------------------------------------------------
  // 5. Notification Permission Methods
  // -------------------------------------------------------------------------

  Future<void> requestNotificationPermission() async {
    try {
      await _platform.invokeMethod('requestNotificationPermission');
    } on PlatformException catch (e) {
      debugPrint("Failed to request notification permission: '${e.message}'.");
    }
  }
  
  Future<bool> checkNotificationPermission() async {
    try {
      final bool granted = await _platform.invokeMethod('checkNotificationPermission');
      return granted;
    } on PlatformException catch (e) {
      debugPrint("Failed to check notification permission: '${e.message}'.");
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Helper function to efficiently parse the list of maps into AppInfo objects
  // -------------------------------------------------------------------------

  static List<AppInfo> _parseApps(List<Map<String, dynamic>> appsData) {
    return appsData.map((map) => AppInfo.fromMap(map)).toList();
  }
}
