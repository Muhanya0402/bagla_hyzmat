import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ── Release signing config ─────────────────────────────────────────────────
// `android/key.properties` НЕ должен быть в git (см. .gitignore).
// Формат:
//   storePassword=<your store password>
//   keyPassword=<your key password>
//   keyAlias=upload
//   storeFile=upload.jks
//
// Создание keystore:
//   keytool -genkey -v -keystore android/app/upload.jks \
//     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.bagla"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.bagla"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Только создаётся если key.properties существует.
        // Иначе release-build упадёт с ясной ошибкой о signing config.
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file("${it}") }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // ⚠️ ВАЖНО: если `key.properties` ещё не создан — release-сборка
            // будет подписана debug-ключом (для локальной отладки release).
            // Для prod-выкладки СНАЧАЛА создать keystore (см. инструкцию выше).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // ── Обфускация + минификация (R8) ────────────────────────────
            // Скрывает имена классов / методов / констант от reverse-eng.
            // Dart-код обфусцируется параллельно при сборке:
            //   flutter build apk --release --obfuscate \
            //     --split-debug-info=build/symbols
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
}