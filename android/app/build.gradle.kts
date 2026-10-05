import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import org.gradle.api.DefaultTask
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.tasks.InputDirectory
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.OutputFile
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction
import org.jetbrains.kotlin.konan.properties.Properties
import java.security.MessageDigest

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val agpMajorVersion = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION
    .substringBefore('.')
    .toInt()
val builtInKotlinProperty = providers.gradleProperty("android.builtInKotlin").orNull
val isBuiltInKotlinEnabled = agpMajorVersion >= 9 &&
        (builtInKotlinProperty == null || builtInKotlinProperty.toBoolean())
if (!isBuiltInKotlinEnabled) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

abstract class GenerateDesktopIconResources : DefaultTask() {
    @get:InputDirectory
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val iconSourceDirectory: DirectoryProperty

    @get:OutputDirectory
    abstract val resourceDirectory: DirectoryProperty

    @get:OutputFile
    abstract val manifestFile: RegularFileProperty

    @TaskAction
    fun generate() {
        val sourceDirectory = iconSourceDirectory.get().asFile
        val resourceRoot = resourceDirectory.get().asFile
        val drawableDirectory = resourceRoot.resolve("drawable-nodpi")

        project.delete(resourceRoot)
        drawableDirectory.mkdirs()

        val icons = sourceDirectory.listFiles()
            ?.filter {
                it.isFile &&
                    it.name.lowercase().startsWith("launcher_") &&
                    when (it.extension.lowercase()) {
                        "png", "jpg", "jpeg", "webp" -> true
                        else -> false
                    }
            }
            ?.sortedBy { it.name }
            ?: emptyList()

        val manifest = buildString {
            append(
                """
                <?xml version="1.0" encoding="utf-8"?>
                <manifest xmlns:android="http://schemas.android.com/apk/res/android">
                    <application>
                """.trimIndent(),
            )
            append('\n')

            icons.forEach { file ->
                val id = iconId(file.name)
                val extension = when (file.extension.lowercase()) {
                    "jpeg" -> "jpg"
                    else -> file.extension.lowercase()
                }
                val resourceName = "desktop_icon_$id"
                file.copyTo(
                    drawableDirectory.resolve("$resourceName.$extension"),
                    overwrite = true,
                )

                append(
                    """
                        <activity-alias
                            android:name=".DesktopIcon_$id"
                            android:enabled="false"
                            android:exported="true"
                            android:icon="@drawable/$resourceName"
                            android:label="@string/app_name"
                            android:targetActivity=".MainActivity">
                            <intent-filter>
                                <action android:name="android.intent.action.MAIN" />
                                <category android:name="android.intent.category.LAUNCHER" />
                            </intent-filter>
                        </activity-alias>
                    """.trimIndent(),
                )
                append('\n')
            }

            append(
                """
                    </application>
                </manifest>
                """.trimIndent(),
            )
            append('\n')
        }

        manifestFile.get().asFile.apply {
            parentFile.mkdirs()
            writeText(manifest)
        }
    }

    private fun iconId(fileName: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(fileName.toByteArray(Charsets.UTF_8))
        return digest.take(12).joinToString("") { "%02x".format(it.toInt() and 0xff) }
    }
}

val desktopIconResourcesTask = tasks.register<GenerateDesktopIconResources>(
    "generateDesktopIconResources",
) {
    iconSourceDirectory.set(
        rootProject.projectDir.parentFile.resolve("assets/images/logo"),
    )
    resourceDirectory.set(
        layout.buildDirectory.dir("generated/desktopIcon/res"),
    )
    manifestFile.set(
        layout.buildDirectory.file("generated/desktopIcon/AndroidManifest.xml"),
    )
}

android {
    namespace = "com.example.pilibro"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "org.BroTech.gege.pilibro"
        minSdk = flutter.minSdkVersion
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packagingOptions.jniLibs.useLegacyPackaging = true

    val keyProperties = Properties().also {
        val properties = rootProject.file("key.properties")
        if (properties.exists())
            it.load(properties.inputStream())
    }

    val config = keyProperties.getProperty("storeFile")?.let {
        signingConfigs.create("release") {
            storeFile = file(it)
            storePassword = keyProperties.getProperty("storePassword")
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildFeatures {
        if (project.hasProperty("dev")) {
            resValues = true
        }
    }

    buildTypes {
        all {
            signingConfig = config ?: signingConfigs["debug"]
        }
        release {
            if (project.hasProperty("dev")) {
                resValue(
                    type = "string",
                    name = "app_name",
                    value = "PiliBro",
                )
            }
//            proguardFiles(
//                getDefaultProguardFile("proguard-android-optimize.txt"),
//                "proguard-rules.pro"
//            )
        }
        debug {
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs.forEach { output ->
            (output as ApkVariantOutputImpl).versionCodeOverride = flutter.versionCode
        }
    }
}

androidComponents {
    onVariants {
        sources.res?.addGeneratedSourceDirectory(
            desktopIconResourcesTask,
            GenerateDesktopIconResources::resourceDirectory,
        )
        sources.manifests.addGeneratedManifestFile(
            desktopIconResourcesTask,
            GenerateDesktopIconResources::manifestFile,
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
