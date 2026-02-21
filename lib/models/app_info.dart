import 'dart:typed_data';

// The data model for an installed application.
class AppInfo {
  // Unique identifier for the app on Android (e.g., "com.google.android.youtube")
  final String packageName;

  // Display name of the application (e.g., "YouTube")
  final String appName;

  // The icon data represented as raw bytes (PNG format)
  final Uint8List? iconBytes;

  AppInfo({
    required this.packageName,
    required this.appName,
    this.iconBytes,
  });

  // Factory constructor to create an AppInfo object from the Map returned by Kotlin.
  factory AppInfo.fromMap(Map<String, dynamic> map) {
    return AppInfo(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      iconBytes: map['iconBytes'] as Uint8List?,
    );
  }

  @override
  String toString() {
    return 'AppInfo(appName: $appName, packageName: $packageName)';
  }
}
