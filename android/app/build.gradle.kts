import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ars.shopy_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // Load keystore props from android/key.properties
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties") // android/key.properties
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    defaultConfig {
        applicationId = "com.ars.shopy_app"
        minSdk = flutter.minSdkVersion

        // ✅ for normal Android build (Play/shareable)
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ✅ Flavors
    flavorDimensions += "env"
    productFlavors {
        create("standard") {
            dimension = "env"
            // standard = normal Android
            targetSdk = flutter.targetSdkVersion
        }

        create("clover") {
            dimension = "env"
            // clover = strict requirements
            targetSdk = 29
        }
    }

    // ✅ Prevent Clover release from failing due to targetSdk 29 lint
    lint {
        abortOnError = false
        checkReleaseBuilds = false
        disable.add("ExpiredTargetSdkVersion")
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            if (!storeFilePath.isNullOrBlank()) storeFile = file(storeFilePath)

            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // ✅ Variant-wise signing scheme control
    // standard: v2/v3 ON (normal)
    // clover:   v1 ON, v2/v3 OFF
    androidComponents {
        onVariants { variant ->
            val isClover = variant.flavorName == "clover"
            variant.packaging.jniLibs.useLegacyPackaging.set(isClover) // optional help for old devices

            variant.signingConfig?.let { sc ->
                if (isClover) {
                    sc.enableV1Signing.set(true)
                    sc.enableV2Signing.set(false)
                    sc.enableV3Signing.set(false)
                } else {
                    sc.enableV1Signing.set(true)
                    sc.enableV2Signing.set(true)
                    sc.enableV3Signing.set(true)
                }
            }
        }
    }
}

flutter {
    source = "../.."
}
