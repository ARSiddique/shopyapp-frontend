buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Android Gradle Plugin compatible with Gradle 8.9
        classpath 'com.android.tools.build:gradle:8.6.1'

        // Google Services (for google-services.json processing)
        classpath 'com.google.gms:google-services:4.4.2'

        // Kotlin (Flutter template still uses 1.9.x)
        classpath 'org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24'
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Flutter expects this:
task clean(type: Delete) {
    delete rootProject.buildDir
}
