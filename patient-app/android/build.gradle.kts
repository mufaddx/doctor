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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
