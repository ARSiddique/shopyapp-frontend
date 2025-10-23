import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")      // updated plugin id
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.ars.shopyapp"
    compileSdk = 35
    // buildToolsVersion removed (AGP will choose a compatible version)
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ars.shopyapp"
        minSdk = 21
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing (guarded; builds even if key.properties is missing)
    val hasKeys = keystoreProperties.containsKey("storeFile")
    signingConfigs {
        if (hasKeys) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String

                // [CLOVER] Force V1-only signing for Clover/POS compatibility
                enableV1Signing = true     // [CLOVER] REQUIRED
                enableV2Signing = false    // [CLOVER] disable
                enableV3Signing = false    // [CLOVER] disable (no incremental signing)
                enableV4Signing = false    // [CLOVER] disable
            }
        }
    }

    buildTypes {
        release {
            if (hasKeys) {
                signingConfig = signingConfigs.getByName("release")
            }
            // Enable later if needed:
            // isMinifyEnabled = true
            // isShrinkResources = true
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
            // [CLOVER] Keep minify/shrink off while validating on POS devices
        }
        debug {
            // default debug signing
        }
    }
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    kotlinOptions { jvmTarget = "17" }
}

flutter {
    source = "../.."
}
