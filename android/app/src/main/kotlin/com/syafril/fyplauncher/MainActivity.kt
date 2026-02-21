package com.syafril.fyplauncher

import android.app.WallpaperManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.app.usage.UsageStatsManager
import android.provider.Settings
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream
import java.util.Calendar
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    // This MUST match the string used in the Dart code (AppService.dart)
    private val CHANNEL = "com.syafril.fyplauncher/app_manager" 

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            
            // Check which method the Dart code is calling
            when (call.method) {
                "getAllApps" -> {
                    // Run on background thread to prevent UI freeze
                    Thread {
                         val appsList = getAllInstalledApps(this.context)
                         runOnUiThread {
                            result.success(appsList)
                         }
                    }.start()
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName") 
                    if (packageName != null) {
                        launchAppByPackageName(packageName)
                        result.success(null) // Operation successful
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required.", null)
                    }
                }
                "checkUsagePermission" -> {
                    result.success(checkUsagePermission())
                }
                "requestUsagePermission" -> {
                    requestUsagePermission()
                    result.success(null)
                }
                "getUsageStats" -> {
                    if (checkUsagePermission()) {
                        result.success(getUsageStats())
                    } else {
                        result.error("PERMISSION_DENIED", "Usage Access Permission not granted", null)
                    }
                }
                "setWallpaper" -> {
                    try {
                        setSolidColorWallpaper(Color.parseColor("#1A1F38")) // Dark Navy
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WALLPAPER_ERROR", "Failed to set wallpaper", e.localizedMessage)
                    }
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success(null)
                }
                "checkNotificationPermission" -> {
                    result.success(checkNotificationPermission())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkNotificationPermission(): Boolean {
        val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return enabledListeners != null && enabledListeners.contains(packageName)
    }

    private fun requestNotificationPermission() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    private fun setSolidColorWallpaper(color: Int) {
        val wallpaperManager = WallpaperManager.getInstance(this)
        // Create a small 1x1 pixel bitmap with the desired color
        val bitmap = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(color)
        wallpaperManager.setBitmap(bitmap)
    }

    // Function to query the Android PackageManager for all installed apps
    private fun getAllInstalledApps(context: Context): List<Map<String, Any>> {
        val packageManager = context.packageManager
        // Query only for packages that have a launcher activity (apps)
        val intent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        
        // Get a list of ResolveInfo objects
        val appList = packageManager.queryIntentActivities(intent, 0)
        
        return appList.map { resolveInfo ->
            // Extract icon
            val iconDrawable = resolveInfo.loadIcon(packageManager)
            val iconBytes = drawableToByteArray(iconDrawable)

            // Create a Map to send data back to Dart
            mapOf(
                "appName" to resolveInfo.loadLabel(packageManager).toString(),
                "packageName" to resolveInfo.activityInfo.packageName,
                "iconBytes" to iconBytes
            )
        }.filter { (it["packageName"] as String) != context.packageName } // Exclude our own launcher app
    }

    // Helper to convert Drawable to ByteArray
    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            // Handle adaptive icons or other drawables
            val bitmap = Bitmap.createBitmap(drawable.intrinsicWidth, drawable.intrinsicHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bitmap
        }
        
        val resizedBitmap = Bitmap.createScaledBitmap(bitmap, 128, 128, true)

        val stream = ByteArrayOutputStream()
        resizedBitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }
    
    // Function to launch an app given its package name
    private fun launchAppByPackageName(packageName: String) {
        val packageManager = context.packageManager
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        
        if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } else {
            println("Error: Could not find launch intent for $packageName")
        }
    }

    private fun checkUsagePermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
        val mode = appOps.checkOpNoThrow(android.app.AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), context.packageName)
        return mode == android.app.AppOpsManager.MODE_ALLOWED
    }

    private fun requestUsagePermission() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    private fun getUsageStats(): Map<String, Long> {
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        val stats = usageStatsManager.queryAndAggregateUsageStats(startTime, endTime)
        
        val result = mutableMapOf<String, Long>()
        for ((packageName, usageStats) in stats) {
            if (usageStats.totalTimeInForeground > 0) {
                result[packageName] = usageStats.totalTimeInForeground
            }
        }
        return result
    }
}
