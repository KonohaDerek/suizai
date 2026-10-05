plugins {
    id("com.android.application")
}

android {
    namespace = "tw.suizai.app"
    compileSdk = 37

    defaultConfig {
        applicationId = "tw.suizai.app"
        minSdk = 26
        targetSdk = 37
        versionCode = 1
        versionName = "0.0.1-poc"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}
