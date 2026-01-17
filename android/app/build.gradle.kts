import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties for release signing
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.vibeplay.vibeplay"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Release signing configuration
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

    defaultConfig {
        applicationId = "com.vibeplay.vibeplay"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Don't compress TFLite model files
    androidResources {
        noCompress += listOf("tflite")
    }

    buildTypes {
        release {
            // Use release signing if key.properties exists, otherwise fall back to debug
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Warning: Debug signing - NOT for production!
                signingConfigs.getByName("debug")
            }

            // Enable code shrinking and obfuscation for release
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
    // TensorFlow Lite for on-device ML genre classification
    // Updated to 2.17.0 for FULLY_CONNECTED op v12 support
    // Note: TFLite 2.17+ uses LiteRT internally
    implementation("org.tensorflow:tensorflow-lite:2.17.0")
    // Exclude old API that conflicts with LiteRT
    implementation("org.tensorflow:tensorflow-lite-support:0.4.4") {
        exclude(group = "org.tensorflow", module = "tensorflow-lite-api")
    }
}

configurations.all {
    resolutionStrategy {
        // Force consistent TensorFlow Lite version
        force("org.tensorflow:tensorflow-lite:2.17.0")
    }
}
