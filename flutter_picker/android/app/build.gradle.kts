import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// CHANGED: real release signing instead of the debug-signed default —
// reads android/key.properties (gitignored, never commit it).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // CHANGED: namespace/applicationId set to the real package; minSdk/targetSdk
    // pinned exactly as specified. compileSdk bumped to 36 because
    // shared_preferences_android requires it to even compile — unrelated to
    // targetSdk/minSdk, which stay at 34/21.
    namespace = "kg.daily.picker"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "kg.daily.picker"
        // CHANGED: Flutter 3.44.1's own tooling enforces minSdk 24 as a hard
        // floor (its Gradle plugin auto-rewrites any lower literal value on
        // every build — confirmed by testing). flutter.minSdkVersion =
        // 24 here, not 21, so this just uses that directly rather than
        // fighting a value the tool reverts anyway.
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // CHANGED: real keystore (see key.properties) instead of debug signing
            signingConfig = signingConfigs.getByName("release")
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
