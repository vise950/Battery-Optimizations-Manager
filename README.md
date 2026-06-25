🔋 Battery Optimizations Manager
A Flutter + Android app to view and manage battery optimization settings for all installed apps on your device. It supports both standard Android API and advanced whitelist management via Shizuku.

📱 Features
📋 List all installed apps (user-installed only, system apps excluded)

🔍 Detail screen for each app showing:

Package name, version name and version code

Current battery optimization status (active / ignored)

⚡ Request battery optimization exemption for a specific app (direct or fallback mode)

⚙️ Open system battery optimization settings directly from the app

🛡️ Shizuku integration for advanced management without root:

Add / remove apps from the Device Idle whitelist

Batch add multiple apps to the whitelist

Check whitelist status per app

Retrieve the full power-save whitelist

🏗️ Tech Stack
Layer

Technology

UI

Flutter (Dart)

Native bridge

Kotlin — MethodChannel

Advanced permissions

Shizuku (rikka.shizuku)

Android API

PowerManager, DeviceIdleController (AIDL)

Min SDK

Android 6.0+ (API 23)

📁 Project Structure

Copy
battery_optimizations_manager/
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml           # Permissions & activity config
│       ├── kotlin/.../
│       │   ├── MainActivity.kt           # MethodChannel handler
│       │   ├── ShizukuHelper.kt          # Shizuku + DeviceIdle bridge
│       │   └── IDeviceIdleController.aidl
│       └── res/
│           ├── drawable/
│           │   ├── ic_launcher_foreground.png   # Adaptive icon foreground
│           │   ├── ic_launcher_background.png   # Adaptive icon background
│           │   └── launch_background.xml
│           ├── drawable-v21/
│           │   └── launch_background.xml
│           ├── mipmap-anydpi-v26/
│               ├── ic_launcher.xml              # Adaptive icon definition
│               └── ic_launcher_round.xml
└── lib/
├── models/
│   └── app_info.dart
├── services/
│   └── apps_channel.dart             # Dart-side MethodChannel wrapper
└── screens/
├── app_list_screen.dart          # Main list of installed apps
└── app_detail_screen.dart        # Per-app detail & battery controls
🔐 Required Permissions
Declared in AndroidManifest.xml:


Copy
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />

⚠️ QUERY_ALL_PACKAGES requires justification if publishing on the Play Store. Use it only for internal/enterprise distribution or file a valid use-case declaration with Google.

🧩 Shizuku Setup
Shizuku allows the app to call privileged Android APIs (like IDeviceIdleController) without root, using ADB authorization.

Steps to enable Shizuku:
Install the Shizuku app from the Play Store.

Start Shizuku via ADB:


Copy
adb shell sh /sdcard/Android/data/moe.shizuku.privileged.api/start.sh
Or use Wireless ADB on Android 11+.

Open this app — it will automatically request Shizuku permission on first launch.

What Shizuku enables:
Feature

Without Shizuku

With Shizuku

Check battery optimization

✅

✅

Open system settings

✅

✅

Add app to Device Idle whitelist

❌

✅

Remove app from whitelist

❌

✅

Batch whitelist management

❌

✅

🚀 Getting Started
Prerequisites
Flutter SDK ≥ 3.x

Android Studio / VS Code

Android device or emulator (API 23+)

Run the app

Copy
git clone https://github.com/your-username/battery_optimizations_manager.git
cd battery_optimizations_manager
flutter pub get
flutter run
Build APK

Copy
flutter build apk --release

Method

Parameters

Returns

Description

getInstalledApps

—

List<Map>

Returns all user-installed apps with name, packageName, versionName, versionCode, icon (PNG bytes)

openBatteryOptimizationSettings

—

null

Opens system battery optimization settings

requestIgnoreBatteryOptimization

packageName: String

"direct" or "fallback"

Requests exemption for a specific app

isIgnoringBatteryOptimizations

packageName: String

Boolean

Returns true if app is already exempt

📝 Known Limitations
Direct exemption request (ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS) may not be supported on all OEM devices (e.g. MIUI, One UI). The app falls back to the general settings screen in that case.

Shizuku whitelist management uses internal AIDL transaction codes that may change across Android versions.

The app does not support system apps — only user-installed applications are shown.