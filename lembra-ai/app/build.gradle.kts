plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.devtools.ksp")
}

val numeroVersao = (System.getenv("VERSION_CODE") ?: "1").toInt()

android {
    namespace = "com.pausa029.lembraai"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.pausa029.lembraai"
        minSdk = 26
        targetSdk = 35
        versionCode = numeroVersao
        versionName = "1.0.$numeroVersao"
    }

    // Chave de TESTE fixa: assim cada APK novo instala por cima do anterior sem apagar a agenda.
    // Para publicar de verdade, veja "APK assinado" no README.
    signingConfigs {
        create("teste") {
            storeFile = file("lembra-teste.jks")
            storePassword = "lembrateste"
            keyAlias = "lembra"
            keyPassword = "lembrateste"
        }
        val arquivo = System.getenv("LEMBRA_KEYSTORE")
        if (arquivo != null) {
            create("publicacao") {
                storeFile = file(arquivo)
                storePassword = System.getenv("LEMBRA_KEYSTORE_SENHA")
                keyAlias = System.getenv("LEMBRA_KEY_ALIAS")
                keyPassword = System.getenv("LEMBRA_KEY_SENHA")
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("teste")
        }
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.findByName("publicacao") ?: signingConfigs.getByName("teste")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
    packaging { resources { excludes += "/META-INF/{AL2.0,LGPL2.1}" } }
}

dependencies {
    implementation(project(":core"))

    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")

    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    ksp("androidx.room:room-compiler:2.6.1")

    implementation("androidx.work:work-runtime-ktx:2.10.0")

    // QR code: gerar (zxing) e ler pela câmera sem pedir permissão (leitor do Google Play Services)
    implementation("com.google.zxing:core:3.5.3")
    implementation("com.google.android.gms:play-services-code-scanner:16.1.0")
}
