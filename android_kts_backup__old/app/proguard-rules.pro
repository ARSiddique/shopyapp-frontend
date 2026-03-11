# Keep Flutter & entry points
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Play Core / SplitInstall keep (R8 missing classes guard)
-keep class com.google.android.play.** { *; }
-dontwarn com.google.android.play.**

# (Optional) Firebase Crashlytics safe keep
-keepattributes *Annotation*
-keep class com.google.firebase.crashlytics.** { *; }

# (Optional) Gson/Kotlin serialization
-keep class com.google.gson.** { *; }
-keep class kotlinx.** { *; }

# Don’t warn on these common libs
-dontwarn java.awt.**
-dontwarn javax.**
