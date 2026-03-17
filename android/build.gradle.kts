
// --- BURAYI EKLE (BAŞLANGIÇ) ---
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Firebase için gerekli olan hayati satır bu:
        classpath("com.google.gms:google-services:4.4.2")
    }
}
// --- BURAYI EKLE (BİTİŞ) ---

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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
