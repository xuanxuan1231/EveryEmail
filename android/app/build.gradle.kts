import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release 签名：从 android/key.properties 读取（CI 会用 secrets 写出该文件）。
// 本地若无该文件，则回退 debug 签名，保证协作者 `flutter build apk --release` 不被卡。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
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

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // key.properties 存在（CI 或本地已配正式签名）→ 用 release 签名；
            // 否则回退 debug 签名，便于本地调试与未配置密钥的协作者构建。
            signingConfig = if (keystorePropertiesFile.exists()) {
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

dependencies {
    // flutter_local_notifications 21.x 要求的核心库脱糖运行时。
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
