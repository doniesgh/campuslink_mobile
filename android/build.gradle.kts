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
// file_picker 11 skips the Kotlin plugin on AGP 9 and counts on built-in Kotlin,
// which gradle.properties turns off (android.builtInKotlin=false). Flutter adds
// Kotlin to plugins that need it, but skips file_picker because its build file
// mentions Kotlin. So nothing compiled its Kotlin code and the build failed on
// "cannot find symbol FilePickerPlugin". Remove this once file_picker is 13+
// (blocked for now: it needs win32 6, flutter_secure_storage 9 needs win32 5).
subprojects {
    if (name == "file_picker") {
        pluginManager.withPlugin("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
            extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
                compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
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
