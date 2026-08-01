plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.touchofcure.touch_of_cure"
    // agora_rtc_engine's transitive androidx deps require compileSdk 34+
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications needs this for java.time APIs on older API levels
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.touchofcure.patient"
        // agora_rtc_engine and recent Firebase plugins require API 23+
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Passed with -PMAPS_API_KEY=xxx or the GOOGLE_MAPS_API_KEY env var so the
        // key is never hard-coded into a tracked manifest file.
        manifestPlaceholders["mapsApiKey"] =
            (project.findProperty("MAPS_API_KEY") as String?)
                ?: System.getenv("GOOGLE_MAPS_API_KEY")
                ?: ""
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

// agora_rtc_engine's original io.agora.rtc:agora-special-full AAR declares the
// same manifest package as io.agora.rtc:iris-rtc, which AGP now rejects as a
// duplicate namespace. The artifact carries no code or resources of its own
// (just native .so libraries), so a local copy with the package renamed is a
// safe drop-in replacement — see android/app/libs/agora-special-full-patched.aar.
configurations.all {
    exclude(group = "io.agora.rtc", module = "agora-special-full")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(files("libs/agora-special-full-patched.aar"))
}
