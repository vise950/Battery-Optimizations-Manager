package com.nik.battery_optimizations_manager

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import androidx.core.graphics.createBitmap
import androidx.core.net.toUri

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.nik.battery_optimizations_manager/apps"
    private val SHIZUKU_PERMISSION_REQUEST_CODE = 100

    @RequiresApi(Build.VERSION_CODES.P)
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    try {
                        val apps = getInstalledApps()
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }

                "openBatteryOptimizationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }

                "requestIgnoreBatteryOptimization" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName == null) {
                        result.error("ERROR", "packageName richiesto", null)
                        return@setMethodCallHandler
                    }

                    when {
                        // Shizuku disponibile e autorizzato
                        ShizukuHelper.isAvailable() -> {
                            try {
                                val success = ShizukuHelper.addToWhitelist(packageName)
                                result.success(if (success) "shizuku_success" else "shizuku_failed")
                            } catch (e: Exception) {
                                result.error("SHIZUKU_ERROR", e.message, null)
                            }
                        }
                        // Shizuku attivo ma senza permesso
                        ShizukuHelper.isRunning() -> {
                            ShizukuHelper.requestPermission(SHIZUKU_PERMISSION_REQUEST_CODE)
                            result.success("shizuku_permission_needed")
                        }
                        // Fallback: intent standard (funziona solo per la propria app)
                        else -> {
                            val directIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = "package:$packageName".toUri()
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            try {
                                if (directIntent.resolveActivity(packageManager) != null) {
                                    startActivity(directIntent)
                                    result.success("direct")
                                } else {
                                    startActivity(fallbackIntent)
                                    result.success("fallback")
                                }
                            } catch (_: Exception) {
                                try {
                                    startActivity(fallbackIntent)
                                    result.success("fallback")
                                } catch (e2: Exception) {
                                    result.error("ERROR", e2.message, null)
                                }
                            }
                        }
                    }
                }

                "removeFromWhitelist" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName == null) {
                        result.error("ERROR", "packageName richiesto", null)
                        return@setMethodCallHandler
                    }
                    if (ShizukuHelper.isAvailable()) {
                        val success = ShizukuHelper.removeFromWhitelist(packageName)
                        result.success(success)
                    } else {
                        result.error("SHIZUKU_UNAVAILABLE", "Shizuku non disponibile", null)
                    }
                }

                "whitelistAllApps" -> {
                    if (ShizukuHelper.isAvailable()) {
                        try {
                            val packages = packageManager
                                .getInstalledApplications(PackageManager.GET_META_DATA)
                                .filter { it.flags and ApplicationInfo.FLAG_SYSTEM == 0 }
                                .map { it.packageName }

                            val (success, failed) = ShizukuHelper.addAllToWhitelist(packages)
                            result.success(mapOf(
                                "total" to packages.size,
                                "whitelisted" to success,
                                "failed" to failed
                            ))
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    } else {
                        result.error("SHIZUKU_UNAVAILABLE", "Shizuku non disponibile o non autorizzato", null)
                    }
                }

                "isShizukuAvailable" -> {
                    result.success(ShizukuHelper.isAvailable())
                }

                "isShizukuRunning" -> {
                    result.success(ShizukuHelper.isRunning())
                }

                "isIgnoringBatteryOptimizations" -> {
                    try {
                        val packageName = call.argument<String>("packageName")
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun getInstalledApps(): List<Map<String, Any?>> {
        val pm: PackageManager = packageManager
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        return packages
            .filter { it.flags and ApplicationInfo.FLAG_SYSTEM == 0 && it.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP == 0 }
            .map { appInfo ->
                val icon = drawableToBytes(pm.getApplicationIcon(appInfo))
                mapOf(
                    "name" to (pm.getApplicationLabel(appInfo).toString()),
                    "packageName" to appInfo.packageName,
                    "versionName" to (pm.getPackageInfo(appInfo.packageName, 0).versionName ?: ""),
                    "versionCode" to pm.getPackageInfo(appInfo.packageName, 0).longVersionCode,
                    "icon" to icon
                )
            }
            .sortedBy { it["name"] as String }
    }

    private fun drawableToBytes(drawable: Drawable): ByteArray {
        val bitmap = createBitmap(
            drawable.intrinsicWidth.coerceAtLeast(1),
            drawable.intrinsicHeight.coerceAtLeast(1)
        )
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }
}
