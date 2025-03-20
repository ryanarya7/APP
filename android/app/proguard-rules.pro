# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Odoo RPC
-keep class com.odoo.** { *; }

# GSON (if used)
-keep class com.google.gson.** { *; }

# Retrofit (if used)
-keep class retrofit2.** { *; }
-dontwarn retrofit2.**

# OkHttp (if used)
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**

# Other dependencies
-keep class odoo_rpc.** { *; }