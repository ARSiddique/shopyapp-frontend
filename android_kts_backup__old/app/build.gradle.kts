@file:Suppress("UnstableApiUsage")

import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
}

val keystoreProps = Properties()
val keystoreFile = rootProject.file("key.properties")
if (keystoreFile.exists()) {
    FileInputStream(keystoreFile).use { keystoreProps.load(it) }
} else {
    println("WARN: key.properties not found at ${keystoreFile.absolutePath}")
}

android {
    namespace = "com.ars.shopyapp"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.ars.shopyapp"
        minSdk = 23
        targetSdk = 34

        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            val storePassword = keystoreProps.getProperty("storePassword")
            val keyPassword   = keystoreProps.getProperty("keyPassword")
            val keyAlias      = keystoreProps.getProperty("keyAlias")
            val storeFilePath = "../app/upload-keystore.jks"

            val storeExists = file(storeFilePath).exists()
            val hasValues = !storePassword.isNullOrBlank() &&
                            !keyPassword.isNullOrBlank() &&
                            !keyAlias.isNullOrBlank() &&
                            storeExists

            if (hasValues) {
                storeFile = file(storeFilePath)
                this.storePassword = storePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword

                // Clover: V1 only
                isV1SigningEnabled = true
                isV2SigningEnabled = false
                isV3SigningEnabled = false
                isV4SigningEnabled = false
            } else {
                println("WARN: Keystore info missing or JKS not found ($storeFilePath). Release will be unsigned.")
            }
        }
    }

    buildTypes {
        release {
            // For first run, force attach so we FAIL early if keystore info is wrong.
            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug { /* as needed */ }
    }

    lint {
        abortOnError = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    implementation("com.google.firebase:firebase-analytics-ktx")
    // Flutter/Gradle will wire the rest
}
