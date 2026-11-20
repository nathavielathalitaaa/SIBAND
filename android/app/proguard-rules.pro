# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_blue_plus & permission_handler
-keep class com.lib.flutter_blue_plus.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }

# Keep Android Bluetooth GATT callbacks intact
-keepclassmembers class * extends android.bluetooth.BluetoothGattCallback {
    public *;
}

# Flutter optional Play Core deferred components (unused in Siband)
-dontwarn com.google.android.play.core.**

