# R8 вырезает сгенерированную Room базу WorkManager (её тянет AdMob) — крэш на старте.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
# flutter_webrtc ходит в org.webrtc через JNI — R8 не должен ничего вырезать.
-keep class org.webrtc.** { *; }
