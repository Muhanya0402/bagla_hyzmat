# Bagla — ProGuard / R8 rules
#
# Эти правила гарантируют, что критичные классы НЕ обфусцируются:
#  - Flutter engine (нужен интрос native ↔ Dart)
#  - Firebase / GCM (использует reflection)
#  - awesome_notifications (background isolate entry-points)
#  - Dio / Json serialization

# ── Google Play Core (deferred components / split-install) ──────────────────
# Flutter engine ссылается на Play Core классы для отложенных компонентов,
# но мы их не используем и пакет не подключён → R8 падает «Missing class».
# Глушим предупреждения и keep'аем (если вдруг появятся).
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ── Flutter ─────────────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.editing.** { *; }

# ── Firebase / GCM ─────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── awesome_notifications — background isolate ─────────────────────────────
# Static handler `onActionReceivedMethod` помечен @pragma('vm:entry-point').
# Tree-shaker'у в release нужны явные `-keep` чтоб не выбросить класс.
-keep class me.carda.awesome_notifications.** { *; }
-dontwarn me.carda.awesome_notifications.**

# ── flutter_secure_storage ─────────────────────────────────────────────────
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# ── Kotlin metadata (нужно для рефлексии в некоторых либах) ────────────────
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations
-keepattributes AnnotationDefault
-keepclassmembers class * {
    @kotlin.Metadata *;
}

# ── Dio / OkHttp ───────────────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# ── Parcelables ────────────────────────────────────────────────────────────
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# ── Stack trace маппинг — оставляем имена файлов для crash-репортов ────────
-keepattributes SourceFile,LineNumberTable
# Затем `flutter build apk --obfuscate --split-debug-info=build/symbols` —
# debug-symbols для деобфускации.
