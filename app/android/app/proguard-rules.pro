# R8 вырезает сгенерированную Room базу WorkManager (её тянет AdMob) — крэш на старте.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
