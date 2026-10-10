import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/* ------------------ KEYSTORE CONFIG ------------------ */

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("app/src/main/key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Load local.properties
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"


// Load .env file
val envFile = rootProject.file("../.env")
val envProperties = Properties()
if (envFile.exists()) {
    envProperties.load(FileInputStream(envFile))
}

android {
    namespace = "com.nlet.adhisaat_health_care"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }


    defaultConfig {
        minSdk = 24
        targetSdk = 36
        multiDexEnabled = true

        // Inject Google Maps API Key from .env
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] =
            envProperties.getProperty("GOOGLE_MAPS_API_KEY_ANDROID", "")

        // Patrol / Firebase Test Lab
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }

    /* ------------------ SIGNING ------------------ */
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    flavorDimensions += "app"
    productFlavors {
        //flutter build apk -t lib/main_user_dev.dart --flavor user_dev
        //PATH=/usr/bin:$PATH flutter build ipa --flavor user_dev -t lib/main_user_dev.dart --export-options-plist=ios/ExportOptions.plist
        //flutter run --flavor user_dev -t lib/main_user_dev.dart
        create("user_dev") {
            dimension = "app"
            applicationId = "com.adhisaat.app.dev"
            manifestPlaceholders["appName"] = "Adhisaat Dev"
            manifestPlaceholders["deepLinkPath"] = "/booking"
            manifestPlaceholders["FACEBOOK_APP_ID"] = envProperties.getProperty("FACEBOOK_APP_ID_USER", "")
            manifestPlaceholders["FACEBOOK_CLIENT_TOKEN"] = envProperties.getProperty("FACEBOOK_CLIENT_TOKEN_USER", "")
            versionCode = flutterVersionCode.toInt()
            versionName = flutterVersionName
            //ios -> 1.1.3+4
        }
        //flutter build apk -t lib/main_user_prod.dart --flavor user_prod
        //flutter build appbundle -t lib/main_user_prod.dart --flavor user_prod
        //flutter build ipa --flavor user_prod -t lib/main_user_prod.dart
        create("user_prod") {
            dimension = "app"
            applicationId = "com.adhisaat.app" // IOS app bundle id -> com.adhisaat
            manifestPlaceholders["appName"] = "Adhisaat"
            manifestPlaceholders["deepLinkPath"] = "/booking"
            manifestPlaceholders["FACEBOOK_APP_ID"] = envProperties.getProperty("FACEBOOK_APP_ID_USER", "")
            manifestPlaceholders["FACEBOOK_CLIENT_TOKEN"] = envProperties.getProperty("FACEBOOK_CLIENT_TOKEN_USER", "")
            versionCode = 17
            versionName = "1.4.12"
        //ios -> 1.2.10+14
        }
        //flutter build apk -t lib/main_provider_dev.dart --flavor provider_dev
        //flutter build ipa --flavor provider_dev -t lib/main_provider_dev.dart
        //PATH=/usr/bin:$PATH flutter build ipa --flavor provider_dev -t lib/main_provider_dev.dart --export-options-plist=ios/ExportOptions.plist
        create("provider_dev") {
            dimension = "app"
            applicationId = "com.adhisaat.provider.dev"
            manifestPlaceholders["appName"] = "Adhisaat Dev"
            manifestPlaceholders["deepLinkPath"] = "/provider-booking"
            manifestPlaceholders["FACEBOOK_APP_ID"] = ""
            manifestPlaceholders["FACEBOOK_CLIENT_TOKEN"] = ""
            versionCode = 1
            versionName = "1.0.0"
            //ios -> 1.2.1+5
        }
        //flutter build appbundle -t lib/main_provider_prod.dart --flavor provider_prod
        //flutter build ipa --flavor provider_prod -t lib/main_provider_prod.dart
        //flutter build apk -t lib/main_provider_prod.dart --flavor provider_prod
        create("provider_prod") {
            dimension = "app"
            applicationId = "com.adhisaat.provider"
            manifestPlaceholders["appName"] = "Adhisaat Partner"
            manifestPlaceholders["deepLinkPath"] = "/provider-booking"
            manifestPlaceholders["FACEBOOK_APP_ID"] = ""
            manifestPlaceholders["FACEBOOK_CLIENT_TOKEN"] = ""
            versionCode = 11
            versionName = "1.2.8"
            //ios -> 1.2.6+8
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            manifestPlaceholders["GOOGLE_MAPS_API_KEY"] =
                envProperties.getProperty("GOOGLE_MAPS_API_KEY_ANDROID", "")
        }

        debug {
            // uses debug keystore automatically
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    androidTestUtil("androidx.test:orchestrator:1.4.2")
}
