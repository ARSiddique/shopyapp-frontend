pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    // Read flutter.sdk from local.properties
    val localProps = java.util.Properties()
    val localPropsFile = java.io.File(rootDir, "local.properties")
    if (localPropsFile.exists()) {
        localPropsFile.inputStream().use { stream ->
            localProps.load(stream)
        }
    }
    val flutterSdkPath = localProps.getProperty("flutter.sdk")
        ?: error("flutter.sdk not set in local.properties")

    // Add Flutter tool’s Gradle build
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.6.1" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
