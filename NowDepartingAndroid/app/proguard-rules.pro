# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /usr/local/Cellar/android-sdk/24.4.1_1/tools/proguard/proguard-android.txt

# Keep serialization classes
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.move38.nowdeparting.**$$serializer { *; }
-keepclassmembers class com.move38.nowdeparting.** {
    *** Companion;
}
-keepclasseswithmembers class com.move38.nowdeparting.** {
    kotlinx.serialization.KSerializer serializer(...);
}
