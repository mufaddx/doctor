allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Some plugins (e.g. agora_rtc_engine) read this to pick their own
    // compileSdkVersion instead of the low default baked into their build.gradle.
    project.extra["compileSdkVersion"] = 36
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")

    // Several plugins (geocoding_android, etc.) hard-code an old compileSdk in
    // their own build.gradle with no override hook. Forcing it here after
    // evaluation covers those too, on top of the compileSdkVersion extra above.
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
