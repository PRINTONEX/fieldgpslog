allprojects {
    repositories {
        google()
        mavenCentral()
    }
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

// Fix for "Namespace not specified" error in older plugins like isar_flutter_libs
// We apply this BEFORE evaluationDependsOn to avoid "already evaluated" errors
subprojects {
    if (project.name != "app") {
        afterEvaluate {
            if (project.extensions.findByName("android") != null) {
                val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
                if (android.namespace == null) {
                    android.namespace = "com.fieldgpslog.${project.name.replace("-", "_")}"
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
