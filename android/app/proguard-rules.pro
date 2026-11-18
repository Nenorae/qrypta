# Flutter & R8 / Proguard rules

# Google ML Kit Text Recognition
# Suppress missing optional language recognizer classes if not imported
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep Latin text recognizer and Vision API classes from R8 stripping
-keep class com.google.mlkit.vision.text.** { *; }
-keep interface com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.vision.** { *; }

