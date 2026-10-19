plugins {
    id("com.android.application")
}

android {
    namespace = "tw.suizai.app"
    compileSdk = 36
    ndkVersion = "27.2.12479018"

    defaultConfig {
        applicationId = "tw.suizai.app"
        minSdk = 26
        targetSdk = 36
        versionCode = 3
        versionName = "0.0.3-poc"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        ndk { abiFilters += listOf("arm64-v8a", "x86_64") }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}

val buildRustCore by tasks.registering(Exec::class) {
    inputs.dir(rootProject.file("core/src"))
    inputs.file(rootProject.file("core/Cargo.toml"))
    inputs.file(rootProject.file("core/Cargo.lock"))
    inputs.file(rootProject.file(".github/scripts/build-android-core.sh"))
    outputs.dir(layout.buildDirectory.dir("rust"))
    commandLine("bash", rootProject.file(".github/scripts/build-android-core.sh"),
        layout.buildDirectory.dir("rust").get().asFile.absolutePath)
}

tasks.configureEach {
    if (name.startsWith("configureCMake") || name.startsWith("buildCMake")) {
        dependsOn(buildRustCore)
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:core:1.6.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
