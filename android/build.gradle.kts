buildscript {
    repositories { google(); mavenCentral() }
    dependencies {
        classpath("com.android.tools.build:gradle:8.4.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24")
    }
}

allprojects {
    repositories { google(); mavenCentral() }
}

rootProject.buildDir = file("../build")
subprojects {
    buildDir = file("${rootProject.buildDir}/$name")
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
