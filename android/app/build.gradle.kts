plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.everyemail.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 需要核心库脱糖（使用了 java.time 等 API）。
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.everyemail.app"
        // minSdk 24 (Android 7)：flutter_appauth / flutter_secure_storage(v10) / flutter_foreground_task 的稳妥基线。
        minSdk = 34
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // flutter_appauth：OAuth 回调用的自定义 scheme（必须全小写）。Google/Microsoft 重定向均走它。
        manifestPlaceholders += mapOf("appAuthRedirectScheme" to "com.everyemail.app")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    // flutter_local_notifications 21.x 要求的核心库脱糖运行时。
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
