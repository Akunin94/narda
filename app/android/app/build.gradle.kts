import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Ключ подписи релиза: android/key.properties (в git не попадает).
// Пока файла нет, релиз подписывается debug-ключом — сборка AAB всё равно
// проверяется локально, а для загрузки в Play ключ подкладывает владелец.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "uz.uzunnarda.narda"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "uz.uzunnarda.narda"
        // Спека §2 просит minSdk 23, но это недостижимо: flutter 3.44 сам
        // переписывает литерал 23 на свой минимум, а shared_preferences_android
        // требует 24. Оставлен минимум Flutter — сейчас это 24 (Android 7.0).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // AdMob требует app id прямо в манифесте, поэтому он приходит не через
        // --dart-define, а через свойство gradle:
        //   flutter build appbundle -Padmob_app_id=ca-app-pub-XXX~YYY
        // По умолчанию — публичный тестовый app id Google.
        manifestPlaceholders["admobAppId"] =
            (project.findProperty("admob_app_id") as String?)
                ?: "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
