# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Mobile Scanner
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# Shared Preferences
-keep class androidx.preference.** { *; }

# Play Core (for Flutter)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }