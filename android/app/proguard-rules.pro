# ============================================================================
# ProGuard Rules for VibePlay
# ============================================================================

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# VibePlay native audio engine
-keep class com.vibeplay.vibeplay.audio.** { *; }
-keep class com.vibeplay.vibeplay.widget.** { *; }
-keep class com.vibeplay.vibeplay.** { *; }

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-keep class com.google.api.** { *; }

# just_audio
-keep class com.google.android.exoplayer2.** { *; }

# audio_service
-keep class com.ryanheise.audioservice.** { *; }

# Hive database
-keep class hive.** { *; }
-keep class * extends hive.TypeAdapter { *; }

# Gson (used by various libraries)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# OkHttp (used by http package)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep model classes that may be serialized
-keep class * implements java.io.Serializable { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# Android DynamicsProcessing (for equalizer)
-keep class android.media.audiofx.** { *; }

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# Optimization
-optimizationpasses 5
-dontusemixedcaseclassnames
-verbose
