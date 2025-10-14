plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("org.jetbrains.kotlin.android")           // was: kotlin-android
    id("com.google.android.libraries.mapsplatform.secrets-gradle-plugin")
    id("dev.flutter.flutter-gradle-plugin")
    
}

android {
    namespace = "com.example.tourist_app"
    compileSdk = 36                               // was: flutter.compileSdkVersion

    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.tourist_app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36                            // was: 34 / flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
         manifestPlaceholders["MAPS_API_KEY"] = "AIzaSyCHSq6ITZdGYydce409Zbc16Bmp5sNME40"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}


