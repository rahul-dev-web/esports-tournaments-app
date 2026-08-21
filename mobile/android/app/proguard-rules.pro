# WorkManager creates its Room database implementation reflectively at startup.
# AGP 9 / R8 full mode can otherwise remove or alter the generated implementation,
# causing release-only crashes before Flutter starts.
-keep class * extends androidx.room.RoomDatabase { *; }

# Keep WorkManager startup/runtime classes used through AndroidX Startup and reflection.
-keep class androidx.work.** { *; }
