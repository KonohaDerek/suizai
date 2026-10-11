plugins {
    id("com.android.application")
}

android {
    namespace = "tw.suizai.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "tw.suizai.app"
        minSdk = 26
        targetSdk = 36
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
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
