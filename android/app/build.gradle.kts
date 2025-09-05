import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 讀取 key.properties（若不存在就用 debug 簽章，方便本機跑）
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.jia741.irondiary"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    // 建議用 JDK 17；若你暫時只有 JDK 11，就把 17 改回 11
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    dependencies {
    // 放在同一個 dependencies 區塊
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
    }

    defaultConfig {
        applicationId = "com.jia741.irondiary"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 發佈簽章（若 key.properties 存在才建立）
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 有 release 簽章就用；沒有就回退到 debug（僅供本機測試）
            signingConfig =
                if (keystorePropertiesFile.exists())
                    signingConfigs.getByName("release")
                else
                    signingConfigs.getByName("debug")

            // 發佈最佳化（如遇混淆問題可暫時關閉再定位）
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
