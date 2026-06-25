import 'package:flutter/services.dart';
import '../models/app_info.dart';

class AppsChannel {
  static const _channel = MethodChannel(
    'com.nik.battery_optimizations_manager/apps',
  );

  static Future<List<AppInfo>> getInstalledApps() async {
    final List result = await _channel.invokeMethod('getInstalledApps');
    return result
        .map((e) => AppInfo.fromMap(e as Map<Object?, Object?>))
        .toList();
  }

  static Future<void> openBatteryOptimizationSettings() async {
    await _channel.invokeMethod('openBatteryOptimizationSettings');
  }

  /// Returns "direct" if ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS was used,
  /// "fallback" if ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS was used as fallback.
  static Future<String> requestIgnoreBatteryOptimization(
    String packageName,
  ) async {
    final result = await _channel.invokeMethod<String>(
      'requestIgnoreBatteryOptimization',
      {'packageName': packageName},
    );
    return result ?? 'fallback';
  }

  static Future<bool> isIgnoringBatteryOptimizations(String packageName) async {
    final result = await _channel.invokeMethod<bool>(
      'isIgnoringBatteryOptimizations',
      {'packageName': packageName},
    );
    return result ?? false;
  }

  static Future<bool> isShizukuAvailable() async {
    final result = await _channel.invokeMethod<bool>('isShizukuAvailable');
    return result ?? false;
  }

  static Future<bool> isShizukuRunning() async {
    final result = await _channel.invokeMethod<bool>('isShizukuRunning');
    return result ?? false;
  }

  static Future<Map<String, dynamic>?> whitelistAllApps() async {
    final result = await _channel.invokeMethod<Map>('whitelistAllApps');
    return result?.cast<String, dynamic>();
  }

  static Future<bool> removeFromWhitelist(String packageName) async {
    final result = await _channel.invokeMethod<bool>('removeFromWhitelist', {
      'packageName': packageName,
    });
    return result ?? false;
  }
}
