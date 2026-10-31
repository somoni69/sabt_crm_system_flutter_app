# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase & Crashlytics
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Flutter Secure Storage / Tink
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.errorprone.annotations.**

# Flutter Play Store Split / Deferred Components
-dontwarn com.google.android.play.core.**

