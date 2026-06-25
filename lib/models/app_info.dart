import 'dart:typed_data';

class AppInfo {
  final String name;
  final String packageName;
  final String versionName;
  final int versionCode;
  final Uint8List? icon;

  const AppInfo({
    required this.name,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    this.icon,
  });

  factory AppInfo.fromMap(Map<Object?, Object?> map) {
    return AppInfo(
      name: map['name'] as String? ?? '',
      packageName: map['packageName'] as String? ?? '',
      versionName: map['versionName'] as String? ?? '',
      versionCode: (map['versionCode'] as int?) ?? 0,
      icon: map['icon'] != null ? Uint8List.fromList((map['icon'] as List).cast<int>()) : null,
    );
  }
}

