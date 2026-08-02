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
    // their own build.gradle with no override hook. plugins.withId fires as
    // soon as the plugin is applied, which is BEFORE the plugin's own script
    // sets its low compileSdk value — that later line would just overwrite
    // this. afterEvaluate runs once the whole subproject script has executed,
    // so this override applies last and actually sticks.
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.LibraryExtension>()?.let {
            it.compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
