group = "com.kinex.kinex_pose"
version = "1.0"

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.kinex.kinex_pose"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    val camerax = "1.4.2"
    implementation("androidx.camera:camera-core:$camerax")
    implementation("androidx.camera:camera-camera2:$camerax")
    implementation("androidx.camera:camera-lifecycle:$camerax")
    implementation("androidx.camera:camera-view:$camerax")
    // MediaPipe Tasks (PoseLandmarker). Keep the 0.10.x line the training landmarks came from.
    implementation("com.google.mediapipe:tasks-vision:0.10.35")
    // ONNX Runtime: libonnxruntime.so for the Dart FFI binding (lib/features/exercise_ai/core/ort_ffi.dart)
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.31.0")
}
