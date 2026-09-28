# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep native methods
-keepclasseswithmembers class * {
    native <methods>;
}

# AndroidX and Support
-keep class androidx.** { *; }
-dontwarn androidx.**

# File Picker & Share Plus
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }

# Sqflite
-keep class com.tekartik.sqflite.** { *; }

# Supabase / OkHttp / Serialization
-keepattributes *Annotation*,EnclosingMethod,Signature,InnerClasses
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit
-dontwarn okhttp3.**
-dontwarn okio.**

# Printing & PDF
-keep class net.nfet.flutter.printing.** { *; }

# Play core deferred components
-dontwarn com.google.android.play.core.**

